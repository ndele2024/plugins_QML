// =============================================================================
//  PasseurProjet — rapatrier un projet QFieldCloud puis l'ouvrir dans QField
// =============================================================================
//  Dernier maillon des parcours d'ouverture : le serveur a préparé et packagé
//  un projet, il reste à le faire descendre sur l'appareil et à l'ouvrir à la
//  place du projet courant — sans passer par l'écran « Projets ».
//
//  ---------------------------------------------------------------------------
//  LA RECETTE DE QFIELD
//  ---------------------------------------------------------------------------
//  C'est l'enchaînement que QField applique lui-même à un projet qu'il vient
//  de créer (`QfCloudScreen.qml`) :
//
//      1. cloudProjectsModel.appendProject(id, true)
//             → signal projectAppended(projectId, hasError, errorString)
//      2. cloudProjectsModel.projectPackageAndDownload(id)
//             → signal projectDownloaded(projectId, projectName, projectOwner,
//                                        hasError, errorString)
//      3. iface.loadFile(projet.localPath, projet.name)
//
//  L'étape 1 n'est pas facultative : `projectPackageAndDownload` ignore sans
//  rien dire un projet absent du modèle, et un projet que le serveur vient de
//  créer n'y est pas encore.
//
//  `cloudProjectsModel` et `cloudConnection` portent un `objectName` dans
//  `qgismobileapp.qml` (vérifié en v4.2.11 et en master) : on les trouve par
//  `iface.findItemByObjectName`, qui cherche n'importe quel QObject.
//
//  ---------------------------------------------------------------------------
//  POURQUOI DANS main.qml
//  ---------------------------------------------------------------------------
//  `iface.loadFile()` démonte le projet courant. Le plugin d'application
//  survit, mais un passeur posé dans une fenêtre pourrait disparaître avec
//  elle au moment où la réponse arrive. Une seule instance, donc, dans
//  `main.qml`, injectée dans les fenêtres comme la session.
//
//  ---------------------------------------------------------------------------
//  GARDE-FOUS
//  ---------------------------------------------------------------------------
//  - QField doit être connecté à QFieldCloud avec son propre compte : le
//    modèle ne fait rien sans `cloudConnection`. Le jeton d'`ifa_menu`
//    (SessionCloud) ne sert à rien ici.
//  - Des modifications locales non synchronisées bloquent l'ouverture :
//    remplacer le projet courant pourrait les perdre. Le passeur ne pousse
//    pas de lui-même — choix délibéré : c'est au technicien de synchroniser.
//    Les fenêtres appellent `verifier()` **avant** de solliciter le serveur,
//    pour ne pas verrouiller ou créer une unité qu'on ne pourra pas ouvrir.
//  - Le modèle signale certains refus par `warning` (« Project busy. ») et
//    non par le signal de fin : sans l'écouter, l'attente serait éternelle.
//  - Chaque étape a sa borne de temps.
//
//  En cas d'échec, `ouvertureImpossible` est émis : l'appelant retombe sur le
//  dialogue « Projet prêt à ouvrir », comme avant. Le projet reste préparé sur
//  le serveur dans tous les cas.
// =============================================================================

import QtQuick

import org.qfield

QtObject {
  id: passeur

  // ---------------------------------------------------------------------------
  //  Dépendances injectées
  // ---------------------------------------------------------------------------
  // `ServiceValidation` : sait si des deltas attendent d'être poussés.
  property var validation: null

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  // 0 repos · 2 ajout au modèle · 3 téléchargement · 4 ouverture différée
  property int etape: 0
  readonly property bool enCours: etape !== 0

  property string projetAttendu: ""
  property string nomAttendu: ""
  property string contexteAttendu: ""

  // Dernier message d'avancement, "" au repos. Les fenêtres le reprennent
  // dans leur bandeau d'activité : le téléchargement dure, et un toast unique
  // laisserait croire que plus rien ne se passe.
  property string message: ""

  // Résolus à chaque demande, jamais à la construction : le plugin
  // d'application est chargé avant que l'interface de QField soit complète.
  property QtObject modele: null
  property QtObject connexion: null

  signal progression(string message)
  signal projetOuvert(string projetId, string nomProjet)

  // `pret` : le projet est-il bien disponible sur le serveur ? Faux si
  // l'échec laisse un doute — le dialogue de repli adapte son texte.
  signal ouvertureImpossible(string nomProjet, string raison, bool pret)

  property int delaiAjoutMs: 20000
  property int delaiTelechargementMs: 180000

  property Timer garde: Timer {
    repeat: false
    onTriggered: {
      if (passeur.etape === 2)
        passeur.abandonner(qsTr("QField n'a pas pu ajouter le projet à sa liste dans le temps imparti."), true);
      else if (passeur.etape === 3)
        passeur.abandonner(qsTr("Le téléchargement du projet n'est pas terminé dans le temps imparti. Il se poursuit peut-être en arrière-plan."), true);
    }
  }

  // ===========================================================================
  //  API publique
  // ===========================================================================
  //  `contexte` : ce qui vient d'être fait, en une phrase (« L'unité … est
  //  créée et verrouillée à votre nom. »). Facultatif ; placé en tête du
  //  message de repli si l'ouverture automatique échoue.
  function demander(projetId, projetNom, contexte) {
    if (etape !== 0) {
      ouvertureImpossible(projetNom, qsTr("Une autre ouverture de projet est déjà en cours."), true);
      return;
    }

    projetAttendu = "" + projetId;
    nomAttendu = "" + projetNom;
    contexteAttendu = contexte ? "" + contexte : "";

    const empechement = verifier();
    if (empechement !== "") {
      terminerEnEchec(empechement, true);
      return;
    }

    etape = 2;
    garde.interval = delaiAjoutMs;
    garde.restart();
    avancer(qsTr("Récupération du projet %1…").arg(nomAttendu));
    iface.logMessage("[IFA] passeur : appendProject(" + projetAttendu + ")");

    try {
      modele.appendProject(projetAttendu, true);
    } catch (e) {
      abandonner(qsTr("QField a refusé la demande : %1").arg(e), true);
    }
  }

  // Annonce un projet à ouvrir à la main, sans rien tenter : c'est le cas
  // d'un packaging dont l'attente a expiré — le serveur y travaille encore,
  // il n'y a rien à télécharger. Même dialogue de repli que les échecs du
  // passeur (voir `ouvertureImpossible`), `pret` à faux.
  function annoncerOuvertureManuelle(projetNom, texte, pret) {
    ouvertureImpossible("" + projetNom, texte ? "" + texte : "", !!pret);
  }

  // ===========================================================================
  //  Vérifications préalables
  // ===========================================================================
  // Rend "" si tout est en place, sinon la raison lisible de l'empêchement.
  // Publique : les fenêtres l'appellent avant de verrouiller ou de créer une
  // unité, `demander()` la rappelle avant de toucher au projet courant.
  function verifier() {
    modele = iface.findItemByObjectName("cloudProjectsModel");
    connexion = iface.findItemByObjectName("cloudConnection");

    if (!modele || !connexion) {
      iface.logMessage("[IFA] passeur : modele=" + !!modele + " connexion=" + !!connexion);
      return qsTr("Cette version de QField n'expose pas sa liste de projets cloud.");
    }

    const methodes = ["appendProject", "projectPackageAndDownload", "findProject"];
    for (let i = 0; i < methodes.length; ++i) {
      if (typeof modele[methodes[i]] !== "function") {
        iface.logMessage("[IFA] passeur : methode absente " + methodes[i]);
        return qsTr("Cette version de QField ne permet pas le téléchargement automatique.");
      }
    }

    if (connexion.hasToken !== true)
      return qsTr("QField n'est pas connecté à QFieldCloud. Connectez-vous depuis l'écran « Projets » pour que les projets s'ouvrent automatiquement.");

    if (validation && validation.deltasEnAttente)
      return qsTr("Le projet ouvert contient des modifications non synchronisées. Synchronisez-les avant d'ouvrir un autre projet.");

    return "";
  }

  // ===========================================================================
  //  Réponses du modèle
  // ===========================================================================
  property Connections lien: Connections {
    target: passeur.modele
    ignoreUnknownSignals: true

    function onProjectAppended(projectId, hasError, errorString) {
      if (passeur.etape !== 2 || projectId !== passeur.projetAttendu)
        return;

      if (hasError) {
        passeur.abandonner(qsTr("QField n'a pas trouvé le projet sur le serveur : %1").arg(errorString), true);
        return;
      }

      passeur.etape = 3;
      passeur.garde.interval = passeur.delaiTelechargementMs;
      passeur.garde.restart();
      passeur.avancer(qsTr("Téléchargement du projet %1…").arg(passeur.nomAttendu));
      iface.logMessage("[IFA] passeur : projectPackageAndDownload(" + projectId + ")");
      passeur.modele.projectPackageAndDownload(projectId);
    }

    function onProjectDownloaded(projectId, projectName, projectOwner, hasError, errorString) {
      if (passeur.etape !== 3 || projectId !== passeur.projetAttendu)
        return;

      if (hasError) {
        passeur.abandonner(qsTr("Le téléchargement du projet a échoué : %1").arg(errorString), true);
        return;
      }

      passeur.ouvrir();
    }

    // Seul canal de certains refus (« Project busy. »). Tout avertissement
    // reçu pendant une de nos étapes est pris pour le nôtre : mieux vaut un
    // repli manuel de trop qu'une attente sans fin.
    function onWarning(message) {
      if (passeur.etape !== 2 && passeur.etape !== 3)
        return;
      passeur.abandonner(qsTr("QField signale : %1").arg(message), true);
    }
  }

  // ===========================================================================
  //  Ouverture
  // ===========================================================================
  function ouvrir() {
    garde.stop();

    const projet = modele.findProject(projetAttendu);
    if (!projet || !projet.localPath) {
      abandonner(qsTr("Le projet a été téléchargé mais reste introuvable sur l'appareil."), true);
      return;
    }

    const id = projetAttendu;
    const chemin = "" + projet.localPath;
    const nom = projet.name ? "" + projet.name : nomAttendu;

    etape = 4;
    avancer(qsTr("Ouverture du projet %1…").arg(nom));
    iface.logMessage("[IFA] passeur : loadFile(" + chemin + ")");

    // Différé : `loadFile()` démonte le projet courant et ce qui en dépend.
    // L'appeler dans la pile du signal du modèle, c'est détruire le contexte
    // de l'émetteur pendant qu'il émet. QField lui-même ne l'appelle que
    // depuis un geste de l'utilisateur.
    Qt.callLater(function () {
      let ouvert = false;
      try {
        ouvert = iface.loadFile(chemin, nom);
      } catch (e) {
        iface.logMessage("[IFA] passeur : loadFile en echec : " + e);
      }

      passeur.etape = 0;
      passeur.projetAttendu = "";
      passeur.message = "";

      if (ouvert)
        passeur.projetOuvert(id, nom);
      else
        passeur.ouvertureImpossible(nom, passeur.enContexte(qsTr("QField a refusé d'ouvrir le projet téléchargé.")), true);
    });
  }

  // ===========================================================================
  //  Utilitaires
  // ===========================================================================
  function avancer(texte) {
    message = texte;
    progression(texte);
  }

  function abandonner(raison, pret) {
    iface.logMessage("[IFA] passeur : abandon a l'etape " + etape + " — " + raison);
    terminerEnEchec(raison, pret);
  }

  function terminerEnEchec(raison, pret) {
    garde.stop();
    etape = 0;
    message = "";
    const nom = nomAttendu;
    projetAttendu = "";
    ouvertureImpossible(nom, enContexte(raison), pret);
  }

  function enContexte(raison) {
    return contexteAttendu !== "" ? contexteAttendu + "\n\n" + raison : raison;
  }
}
