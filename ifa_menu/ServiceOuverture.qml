// =============================================================================
//  ServiceOuverture — ouverture d'une unité d'échantillonnage dans QField
// =============================================================================
//  Interroge le point d'accès QFieldCloud
//
//      POST /api/v1/ifa/unites/<une_code_ident>/ouvrir/
//
//  servi par l'application Django `qfieldcloud.ifa`. Le serveur y prépare, sous
//  le compte de l'utilisateur, un projet qui ne contient que l'unité demandée :
//  il recopie le projet modèle et remplit son GeoPackage des inventaires de
//  l'unité, puis lance le packaging.
//
//  ---------------------------------------------------------------------------
//  DEUX MODES
//  ---------------------------------------------------------------------------
//      "modifiable"    l'unité est d'abord verrouillée dans la base métier au
//                      nom de l'utilisateur, avec la raison qu'il a saisie ;
//                      le projet livré est modifiable.
//      "consultation"  rien n'est écrit dans la base ; toutes les couches du
//                      projet livré sont en lecture seule.
//
//  ---------------------------------------------------------------------------
//  TROIS TEMPS
//  ---------------------------------------------------------------------------
//  1. `ouvrir()` envoie la demande. Le serveur répond dès que le projet est
//     prêt côté fichiers, en donnant l'identifiant du travail de packaging.
//  2. Le service interroge ensuite `GET /api/v1/jobs/<id>/` jusqu'à ce que ce
//     travail soit terminé — le packaging tourne dans un conteneur QGIS, il
//     prend de quelques secondes à quelques minutes.
//  3. Le projet est remis à `PasseurProjet` (main.qml), qui le télécharge et
//     l'ouvre à la place du projet courant — ou, s'il n'y parvient pas, nomme
//     le projet à ouvrir depuis l'écran « Projets ». L'unité est prête dans
//     tous les cas.
// =============================================================================

import QtQuick

import org.qfield

QtObject {
  id: service

  // ---------------------------------------------------------------------------
  //  Dépendances injectées
  // ---------------------------------------------------------------------------
  property var session: null

  // Rapatrie et ouvre le projet préparé (PasseurProjet.qml), ou l'annonce
  // pour une ouverture manuelle s'il n'y parvient pas.
  property var passeur: null

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  property bool enCours: false

  // Dernier message d'avancement, affichable tel quel.
  property string etape: ""

  // Renseignés dès la réponse du serveur.
  property string uniteCourante: ""
  property string modeCourant: ""
  property string projetId: ""
  property string projetNom: ""
  property string travailId: ""
  property int lignesEcrites: 0

  // État de verrou de l'unité tel que la base le porte après l'ouverture : le
  // tableau des résultats s'en sert pour rafraîchir sa ligne sans relancer la
  // recherche.
  property var uniteVerrou: null

  // Packagé, et remis au passeur pour le téléchargement et l'ouverture.
  signal pret(var infos)

  signal progression(string message)
  signal echec(string message)

  // ---------------------------------------------------------------------------
  //  Interne
  // ---------------------------------------------------------------------------
  // Une demande d'ouverture chasse la précédente : une réponse tardive ne doit
  // pas relancer un sondage abandonné.
  property int demandeCourante: 0

  // Le packaging d'une unité tient en quelques dizaines de secondes ; la borne
  // couvre un serveur chargé sans laisser tourner un sondage indéfini.
  property int intervalleSondageMs: 3000
  property int sondagesMax: 100
  property int sondagesFaits: 0

  property Timer minuterie: Timer {
    interval: service.intervalleSondageMs
    repeat: true
    onTriggered: service.sonder()
  }

  // ===========================================================================
  //  API publique
  // ===========================================================================
  //  `unite`  ligne du tableau des résultats de recherche.
  //  `mode`   "modifiable" ou "consultation".
  //  `raison` motif du verrouillage — exigé en mode modifiable, ignoré sinon.
  function ouvrir(unite, mode, raison) {
    if (!session || !passeur) {
      echec(qsTr("Le service d'ouverture n'est pas relié à la session QFieldCloud."));
      return;
    }

    if (!unite || !unite["une_code_ident"]) {
      echec(qsTr("Unité d'échantillonnage inconnue."));
      return;
    }

    annuler();

    const numero = ++demandeCourante;
    const code = "" + unite["une_code_ident"];

    uniteCourante = code;
    modeCourant = mode;
    projetId = "";
    projetNom = "";
    travailId = "";
    lignesEcrites = 0;
    uniteVerrou = null;
    enCours = true;

    avancer(mode === "modifiable" ? qsTr("Verrouillage de l'unité %1…").arg(code) : qsTr("Préparation de l'unité %1…").arg(code));

    const corps = {
      "mode": mode,
      "raison": raison ? "" + raison : ""
    };

    session.appeler("POST", "/api/v1/ifa/unites/" + encodeURIComponent(code) + "/ouvrir/", corps, function (donnees) {
      if (numero !== service.demandeCourante)
        return;
      service.traiterPreparation(donnees);
    }, function (message) {
      if (numero !== service.demandeCourante)
        return;
      service.terminer(false, message);
    });
  }

  function annuler() {
    demandeCourante++;
    minuterie.stop();
    sondagesFaits = 0;
    enCours = false;
  }

  // ===========================================================================
  //  Préparation
  // ===========================================================================
  function traiterPreparation(donnees) {
    if (!donnees || !donnees.projet_id || !donnees.travail_id) {
      terminer(false, qsTr("Réponse du serveur illisible."));
      return;
    }

    projetId = "" + donnees.projet_id;
    projetNom = "" + (donnees.projet_nom !== undefined ? donnees.projet_nom : "");
    travailId = "" + donnees.travail_id;
    lignesEcrites = donnees.lignes !== undefined ? donnees.lignes : 0;
    uniteVerrou = donnees.unite !== undefined ? donnees.unite : null;

    avancer(qsTr("%n enregistrement(s) préparé(s) — packaging en cours…", "", lignesEcrites));

    sondagesFaits = 0;
    minuterie.interval = intervalleSondageMs;
    minuterie.start();
  }

  // ===========================================================================
  //  Attente du packaging
  // ===========================================================================
  function sonder() {
    if (!enCours) {
      minuterie.stop();
      return;
    }

    if (++sondagesFaits > sondagesMax) {
      terminer(false, qsTr("Le packaging du projet %1 n'est toujours pas terminé. Il se poursuit sur le serveur : ouvrez le projet depuis l'écran « Projets » quand il sera prêt.").arg(projetNom));
      return;
    }

    const numero = demandeCourante;

    session.appeler("GET", "/api/v1/jobs/" + travailId + "/", null, function (donnees) {
      if (numero !== service.demandeCourante)
        return;
      service.traiterEtatTravail(donnees);
    }, function (message) {
      if (numero !== service.demandeCourante)
        return;
      // Un sondage qui échoue n'est pas fatal : le suivant réessaiera. Seul
      // l'épuisement du compteur met fin à l'attente.
      iface.logMessage("[IFA] sondage du packaging en echec : " + message);
    });
  }

  function traiterEtatTravail(donnees) {
    const etat = donnees && donnees.status !== undefined ? "" + donnees.status : "";

    if (etat === "finished") {
      minuterie.stop();
      avancer(qsTr("Projet %1 prêt.").arg(projetNom));
      livrer();
      return;
    }

    if (etat === "failed" || etat === "stopped") {
      terminer(false, qsTr("Le packaging du projet %1 a échoué sur le serveur.").arg(projetNom));
      return;
    }

    if (etat === "queued")
      avancer(qsTr("Packaging en file d'attente…"));
    else if (etat === "started")
      avancer(qsTr("Packaging en cours…"));
  }

  // ===========================================================================
  //  Remise à QField
  // ===========================================================================
  function livrer() {
    const infos = {
      "unite": uniteCourante,
      "mode": modeCourant,
      "projet_id": projetId,
      "projet_nom": projetNom,
      "lignes": lignesEcrites,
      "verrou": uniteVerrou
    };

    enCours = false;
    pret(infos);

    // Le passeur télécharge et ouvre le projet ; s'il n'y parvient pas, il
    // l'annonce lui-même pour une ouverture manuelle (dialogue « Projet prêt à
    // ouvrir », dans main.qml). Le verrou, lui, est déjà posé et le reste.
    const contexte = modeCourant === "modifiable" ? qsTr("L'unité %1 est verrouillée à votre nom.").arg(uniteCourante) : qsTr("L'unité %1 est prête en consultation.").arg(uniteCourante);
    passeur.demander(projetId, projetNom, contexte);
  }

  // ===========================================================================
  //  Utilitaires
  // ===========================================================================
  function avancer(message) {
    etape = message;
    progression(message);
  }

  function terminer(succes, message) {
    minuterie.stop();
    enCours = false;
    etape = "";

    if (!succes)
      echec(message);
  }
}
