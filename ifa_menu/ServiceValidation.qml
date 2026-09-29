// =============================================================================
//  ServiceValidation — rapport de validation IFE du projet ouvert
// =============================================================================
//  Reprend le plugin autonome « Rapport IFE » (`plugin_event.qml`) et le fond
//  dans le plugin IFA : même mécanique, mais la session QFieldCloud est celle
//  de `SessionCloud` — un seul jeton, une seule demande de mot de passe pour
//  tout le programme, au lieu de deux plugins qui se les disputaient.
//
//  ---------------------------------------------------------------------------
//  AUCUNE HORLOGE RÉSEAU
//  ---------------------------------------------------------------------------
//  L'état ne peut changer que dans trois circonstances, toutes connues :
//  ouverture du projet, push du technicien, rafraîchissement manuel. Une
//  requête n'est émise qu'à ces moments-là ; au repos, le service ne parle pas
//  au serveur.
//
//  Le push est connu par le signal **`pushFinished`** de `cloudProjectsModel`,
//  et les modifications en attente par `layerObserver.deltaFileWrapper.count`
//  — deux API de QField (Q_PROPERTY / signal, vérifiés dans les en-têtes
//  v4.2.11), atteintes par `iface.findItemByObjectName`.
//
//  **Secours seulement** : la lecture de `deltafile.json` toutes les 400 ms,
//  que QField vide quand le serveur a accepté le push. C'était le seul
//  mécanisme ; il a manqué des pushes sur le terrain sans laisser de trace —
//  `XMLHttpRequest` sur une URL `file://` peut être refusé par Qt en silence.
//  Il ne sert plus que si le modèle est introuvable.
//
//  ---------------------------------------------------------------------------
//  POURQUOI UNE SÉQUENCE DE TENTATIVES APRÈS LE PUSH
//  ---------------------------------------------------------------------------
//  Le serveur ne rappelle jamais le plugin, et la validation se déroule APRÈS
//  la réponse HTTP du push : une requête unique arriverait trop tôt. On tire
//  donc quelques tentatives espacées, arrêtées dès que le rapport reçu est plus
//  récent que celui affiché — c'est `genere_le` qui en décide, pas un délai.
//
//  ---------------------------------------------------------------------------
//  LE PUSH NE DÉCLENCHE PAS LA SUITE TOUT SEUL
//  ---------------------------------------------------------------------------
//  `pousseDetecte` est émis, et le service s'arrête là. C'est l'appelant qui
//  décide quand commencer à attendre le rapport, par `attendreRapportFrais()` —
//  le temps de demander au technicien s'il veut déverrouiller son unité, et de
//  le faire. Sans cela, les requêtes du rapport partiraient devant la question,
//  et la demande de mot de passe surgirait par-dessus le dialogue.
// =============================================================================

import QtQuick

import org.qfield

Item {
  id: service

  visible: false

  // ---------------------------------------------------------------------------
  //  Dépendances injectées
  // ---------------------------------------------------------------------------
  property var session: null

  // Sert à lire la variable de projet `une_code_ident` : c'est le serveur qui
  // l'a posée dans le projet livré, et c'est la seule chose qui dise quelle
  // unité le projet ouvert porte — son nom ne le dit pas, il est le même d'une
  // unité à la suivante.
  property var referentiels: null

  // ---------------------------------------------------------------------------
  //  Le rapport
  // ---------------------------------------------------------------------------
  property var rapport: null
  property bool charge: false

  // Horodatage du rapport affiché. C'est LUI qui distingue un rapport frais
  // d'un rapport que le serveur n'a pas encore régénéré.
  property string genereLe: ""

  // ---------------------------------------------------------------------------
  //  Les trois incertitudes, qui ne disent pas la même chose
  // ---------------------------------------------------------------------------
  //  deltasEnAttente : le technicien a saisi, rien n'est encore parti
  //  attenteRapport  : c'est parti, le serveur travaille
  //  perime          : on a renoncé à attendre, l'affichage n'engage plus rien
  property bool deltasEnAttente: false
  property bool attenteRapport: false
  property bool perime: false

  // Deux questions différentes, et il a fallu les séparer pour que l'interface
  // dise juste :
  //
  //   « attend-on le serveur ? »        → ce qu'il faut MONTRER (roue, bouton
  //                                       qui bat, message)
  //   « l'affichage engage-t-il ? »     → ce qu'il faut DIRE du rapport affiché
  //
  // Un simple « Rafraîchir » relève de la première et pas de la seconde : le
  // rapport déjà à l'écran reste valable pendant qu'on en redemande un. Les
  // confondre grisait le verdict et faisait clignoter « aucun rapport chargé »
  // à chaque appui.
  readonly property bool enAttenteServeur: attenteRapport || requeteEnCours

  readonly property bool enAttente: deltasEnAttente || attenteRapport
  readonly property bool rapportPret: charge && !enAttente && !perime

  // ---------------------------------------------------------------------------
  //  L'attente telle qu'on la MONTRE
  // ---------------------------------------------------------------------------
  //  `enAttenteServeur` dit la vérité, mais elle ne suffit pas à l'affichage :
  //  contre un serveur local, une requête revient en quelques dizaines de
  //  millisecondes. L'indication apparaît et disparaît dans le même souffle —
  //  personne ne la voit, et le plugin passe pour ne rien signaler du tout.
  //
  //  `attenteVisible` reste donc levée un court instant de plus. C'est du
  //  confort d'affichage, pas de l'information : rien ne s'y décide.
  property bool attenteVisible: false

  property int dureeMinimaleAffichageMs: 1200

  onEnAttenteServeurChanged: {
    if (enAttenteServeur) {
      minuterieAffichage.stop();
      attenteVisible = true;
      return;
    }

    minuterieAffichage.restart();
  }

  Timer {
    id: minuterieAffichage

    interval: service.dureeMinimaleAffichageMs
    repeat: false
    onTriggered: service.attenteVisible = service.enAttenteServeur
  }

  // « valide », « invalide » ou « inconnu » — ce que le bouton de la barre
  // d'outils donne à lire d'un coup d'œil.
  readonly property string etat: {
    if (!rapportPret || !rapport)
      return "inconnu";
    return rapport.is_valid ? "valide" : "invalide";
  }

  readonly property int nombreErreurs: rapport && rapport.error_count !== undefined ? rapport.error_count : 0
  readonly property int nombreAvertissements: rapport && rapport.warning_count !== undefined ? rapport.warning_count : 0

  // Dernier état connu, affichable tel quel dans la fenêtre du rapport.
  property string diagnostic: qsTr("Initialisation…")

  // ---------------------------------------------------------------------------
  //  Signaux
  // ---------------------------------------------------------------------------
  //  Le push vient d'être accepté par le serveur. `codeUnite` est vide quand le
  //  projet ouvert ne dit pas quelle unité il porte.
  signal pousseDetecte(string codeUnite)

  //  Un rapport vient d'être chargé. `apresPousse` distingue celui qu'on
  //  guettait après une synchronisation — le seul qui mérite d'interrompre le
  //  technicien — de celui qu'on lit à l'ouverture d'un projet ou sur demande.
  signal rapportRecu(bool apresPousse)

  signal echec(string message)

  // ---------------------------------------------------------------------------
  //  Le projet ouvert
  // ---------------------------------------------------------------------------
  readonly property string dossierProjet: {
    if (typeof qgisProject === "undefined" || !qgisProject)
      return "";
    return "" + qgisProject.homePath;
  }

  // L'identifiant du projet infonuagique, lu dans le chemin :
  // `…/cloud_projects/<compte>/<uuid>/`. C'est lui qui adresse le paquet.
  readonly property string projetId: {
    const dossier = dossierProjet.replace(/\\/g, "/");

    if (dossier === "")
      return "";

    const parties = dossier.split("/");
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    for (let i = parties.length - 1; i >= 0; --i) {
      if (uuid.test(parties[i]))
        return parties[i];
    }

    return "";
  }

  readonly property string cheminDeltafile: {
    if (dossierProjet === "")
      return "";

    let chemin = ("" + dossierProjet).replace(/\\/g, "/");

    // Une URL `file://` veut un chemin ABSOLU commençant par « / ». Sous
    // Android le chemin commence déjà ainsi ; sous Windows il commence par
    // « C:/ », et sans cet ajout on obtient `file://C:/…` où « C: » est lu
    // comme nom d'hôte — la lecture échoue silencieusement à chaque sondage.
    if (chemin.charAt(0) !== "/")
      chemin = "/" + chemin;

    return "file://" + encodeURI(chemin) + "/deltafile.json";
  }

  // Changer de projet change tout : le rapport affiché n'est plus le sien.
  onProjetIdChanged: reinitialiser()

  // ---------------------------------------------------------------------------
  //  Interne
  // ---------------------------------------------------------------------------
  // Espacement croissant, calé sur la réalité observée : le rapport apparaît
  // généralement entre 5 et 20 s après le push. Une cadence fixe marèlerait
  // pour rien pendant les premières secondes, où il n'a aucune chance d'être
  // prêt.
  readonly property var cadenceTentatives: [2000, 4000, 8000, 15000, 30000]
  property int tentative: 0

  // Mémorise qu'il y avait des deltas, pour repérer l'instant où QField vide le
  // fichier — c'est la signature du push accepté.
  property bool deltasVus: false

  property bool requeteEnCours: false
  property bool lectureDeltaEnCours: false

  // ---------------------------------------------------------------------------
  //  Les signaux natifs de QField
  // ---------------------------------------------------------------------------
  //  Résolu à la volée, pas à la construction : le plugin d'application est
  //  chargé avant que l'interface de QField soit complète.
  property QtObject modeleCloud: null

  // Le compteur de modifications en attente du projet ouvert, ou null.
  readonly property QtObject deltasNatifs: modeleCloud && modeleCloud.layerObserver && modeleCloud.layerObserver.deltaFileWrapper ? modeleCloud.layerObserver.deltaFileWrapper : null

  readonly property bool detectionNative: deltasNatifs !== null

  // Changer de projet change de compteur : relire sa valeur tout de suite.
  onDeltasNatifsChanged: {
    if (deltasNatifs)
      deltasEnAttente = deltasNatifs.count > 0;
  }

  onDetectionNativeChanged: iface.logMessage("[IFA] detection du push : " + (detectionNative ? "signaux de QField" : "lecture de deltafile.json (secours)"))

  Connections {
    target: service.deltasNatifs
    ignoreUnknownSignals: true

    function onCountChanged() {
      service.deltasEnAttente = service.deltasNatifs.count > 0;
    }
  }

  Connections {
    target: service.modeleCloud
    ignoreUnknownSignals: true

    // Le push est terminé, accepté ou non. Seul un push réussi du projet
    // ouvert déclenche la suite.
    function onPushFinished(projectId, isDownloadingProject, hasError, errorString) {
      if (projectId !== service.projetId)
        return;

      if (hasError) {
        iface.logMessage("[IFA] push en echec : " + errorString);
        return;
      }

      service.signalerPousse("signal pushFinished");
    }
  }

  function resoudreModeleCloud() {
    if (modeleCloud)
      return;

    try {
      modeleCloud = iface.findItemByObjectName("cloudProjectsModel");
    } catch (e) {
      modeleCloud = null;
    }

    if (deltasNatifs)
      deltasEnAttente = deltasNatifs.count > 0;
  }

  Component.onCompleted: {
    resoudreModeleCloud();
    sonderDeltas();
    demanderRapportSiPossible();
    minuterieDelta.start();
  }

  // Tant que le modèle n'est pas trouvé : on le recherche, et on lit le
  // fichier en secours. Une fois trouvé, cette horloge ne fait plus rien.
  Timer {
    id: minuterieDelta

    interval: 400
    repeat: true
    onTriggered: service.sonderDeltas()
  }

  function sonderDeltas() {
    resoudreModeleCloud();

    if (!detectionNative)
      lireDeltafile();
  }

  Timer {
    id: minuterieTentative

    repeat: false
    onTriggered: service.demanderRapport()
  }

  // ===========================================================================
  //  API publique
  // ===========================================================================
  //  Rafraîchissement manuel : accepte le rapport tel qu'il vient, sans exiger
  //  qu'il soit plus récent que celui affiché. Part d'un geste de
  //  l'utilisateur, donc la session peut réclamer le mot de passe.
  function rafraichir() {
    annulerTentatives();
    perime = false;
    demanderRapport();
  }

  //  Première lecture, au chargement ou à l'ouverture d'un projet. Personne n'a
  //  rien demandé : si la session devait réclamer le mot de passe, on s'abstient
  //  et on laisse le rapport pour quand on l'ouvrira.
  function demanderRapportSiPossible() {
    if (session && session.jetonDisponible) {
      rafraichir();
      return;
    }

    diagnostic = qsTr("Rapport non chargé : rafraîchissez pour l'obtenir du serveur.");
  }

  //  Commence à guetter un rapport *plus récent* que celui affiché. Appelé
  //  après un push, une fois la question du déverrouillage réglée.
  function attendreRapportFrais() {
    attenteRapport = true;
    perime = false;
    tentative = 0;
    diagnostic = qsTr("Push accepté — attente du rapport de validation…");
    tentativeSuivante();
  }

  function reinitialiser() {
    annulerTentatives();
    rapport = null;
    charge = false;
    genereLe = "";
    perime = false;
    deltasVus = false;
    diagnostic = qsTr("Projet ouvert — lecture du rapport…");
    demanderRapportSiPossible();
  }

  // Code de l'unité que porte le projet ouvert, ou "" si le projet ne le dit
  // pas — un projet qui n'a pas été préparé par les points d'accès IFA.
  function codeUnite() {
    if (!referentiels)
      return "";

    const code = referentiels.variableProjet("une_code_ident");

    return code === undefined || code === null ? "" : "" + code;
  }

  // ===========================================================================
  //  Le fichier de deltas
  // ===========================================================================
  function lireDeltafile() {
    if (cheminDeltafile === "" || lectureDeltaEnCours)
      return;

    lectureDeltaEnCours = true;

    const xhr = new XMLHttpRequest();
    let termine = false;

    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE || termine)
        return;
      termine = true;
      service.lectureDeltaEnCours = false;
      // Sur une URL `file://`, Qt laisse `status` à 0 même en cas de succès :
      // c'est le corps de la réponse qui fait foi, pas le code HTTP.
      service.appliquerNombreDeltas(xhr.responseText);
    };

    try {
      xhr.open("GET", cheminDeltafile);
      xhr.send();
    } catch (e) {
      termine = true;
      lectureDeltaEnCours = false;
    }
  }

  function appliquerNombreDeltas(texte) {
    let nombre = 0;

    if (texte) {
      try {
        const contenu = JSON.parse(texte);
        nombre = contenu.deltas && contenu.deltas.length ? contenu.deltas.length : 0;
      } catch (e) {
        // Fichier en cours d'écriture : le sondage suivant le relira.
        return;
      }
    }

    if (nombre > 0) {
      deltasEnAttente = true;
      deltasVus = true;
      return;
    }

    deltasEnAttente = false;

    // Transition « il y avait des deltas » → « il n'y en a plus » : QField
    // vient de vider le fichier, donc le serveur a accepté le push. C'est
    // l'événement, obtenu sans la moindre requête.
    if (deltasVus) {
      deltasVus = false;
      signalerPousse("deltafile.json vide");
    }
  }

  // Seul endroit d'où part toute la suite (question du déverrouillage, puis
  // attente du rapport), quelle que soit la façon dont le push a été vu.
  // Quand rien ne se passe après une synchronisation, c'est la ligne de
  // journal à chercher.
  function signalerPousse(source) {
    // Un rapport est déjà guetté : un second push pendant l'attente ne doit
    // pas reposer la question.
    if (attenteRapport)
      return;

    const code = codeUnite();

    iface.logMessage("[IFA] push detecte (" + source + ") — unite « " + code + " »");

    pousseDetecte(code);
  }

  // ===========================================================================
  //  Le rapport
  // ===========================================================================
  function demanderRapport() {
    if (requeteEnCours)
      return;

    if (!session) {
      diagnostic = qsTr("Aucune session QFieldCloud.");
      return;
    }

    if (projetId === "") {
      // Rien ne pourra jamais aboutir : le projet ouvert n'est pas un projet
      // infonuagique. Inutile de laisser une attente sans fin.
      diagnostic = qsTr("Le projet ouvert n'est pas un projet QFieldCloud : pas de rapport de validation.");
      if (attenteRapport) {
        annulerTentatives();
        perime = true;
      }
      return;
    }

    requeteEnCours = true;

    // Pendant une séquence d'attente, le message en dit déjà plus que celui-ci
    // (« Validation en cours côté serveur… ») : ne pas l'écraser.
    if (!attenteRapport)
      diagnostic = qsTr("Lecture du rapport sur le serveur…");

    session.appeler("GET", "/api/v1/packages/" + projetId + "/latest/files/rapport_ife.json/", null, function (donnees) {
      service.requeteEnCours = false;
      service.recevoirRapport(donnees);
    }, function (message, statut) {
      service.requeteEnCours = false;
      service.echouerRapport(message, statut);
    });
  }

  function recevoirRapport(donnees) {
    if (!donnees) {
      diagnostic = qsTr("Rapport illisible.");
      if (attenteRapport)
        tentativeSuivante();
      return;
    }

    const horodatage = donnees.genere_le ? "" + donnees.genere_le : "";

    // En attente d'un rapport FRAIS : tant que le serveur rend celui qu'on
    // affiche déjà, c'est qu'il n'a pas fini. On réessaie plus tard sans rien
    // changer à l'affichage.
    if (attenteRapport && horodatage !== "" && horodatage === genereLe) {
      diagnostic = qsTr("Validation en cours côté serveur…");
      tentativeSuivante();
      return;
    }

    // Retenu avant `annulerTentatives()`, qui remet l'attente à zéro.
    const apresPousse = attenteRapport;

    rapport = donnees;
    charge = true;
    genereLe = horodatage;
    annulerTentatives();
    perime = false;
    diagnostic = donnees.is_valid ? qsTr("Rapport chargé : VALIDE") : qsTr("Rapport chargé : INVALIDE");

    rapportRecu(apresPousse);
  }

  function echouerRapport(message, statut) {
    // 404 : le serveur n'a pas (encore) produit de rapport. Ce n'est pas une
    // panne — c'est l'état normal avant la première validation, et l'état
    // transitoire juste après un push.
    if (statut === 404) {
      if (attenteRapport) {
        diagnostic = qsTr("Validation en cours côté serveur…");
        tentativeSuivante();
        return;
      }

      diagnostic = qsTr("Aucun rapport sur le serveur : la validation n'a pas encore été exécutée.");
      return;
    }

    diagnostic = message;

    if (attenteRapport) {
      tentativeSuivante();
      return;
    }

    echec(message);
  }

  // ===========================================================================
  //  Séquence de tentatives
  // ===========================================================================
  function tentativeSuivante() {
    if (tentative >= cadenceTentatives.length) {
      // Fenêtre épuisée. On cesse d'attendre, mais on ne fait pas croire que
      // l'affichage est à jour : l'état passe à « périmé » et la fenêtre
      // invite à rafraîchir.
      attenteRapport = false;
      perime = true;
      diagnostic = qsTr("Rapport toujours pas disponible — utilisez « Rafraîchir ».");
      return;
    }

    minuterieTentative.interval = cadenceTentatives[tentative];
    tentative++;
    minuterieTentative.restart();
  }

  function annulerTentatives() {
    minuterieTentative.stop();
    attenteRapport = false;
    tentative = 0;
  }
}
