// =============================================================================
//  ServiceFormulaire — préparation du projet de saisie d'une nouvelle UE
// =============================================================================
//  Interroge le point d'accès QFieldCloud
//
//      POST /api/v1/ifa/formulaire/preparer/
//
//  servi par l'application Django `qfieldcloud.ifa`. Le serveur y fait deux
//  choses :
//
//    * il **crée l'unité** dans la base métier — inscrite dans `unite_echan` et
//      verrouillée au nom de l'utilisateur, avec la raison « nouvelle Unité
//      d'échantillonnage ». C'est ce qui réserve son code ;
//    * il prépare, sous le compte de l'utilisateur, le projet
//      `formulaire_UE_IFA` : recopie du dernier paquet du projet modèle,
//      remplissage du GeoPackage des données que le technicien a choisi
//      d'embarquer — la nouvelle unité comprise — et pose des variables de
//      projet qui alimentent les valeurs par défaut du formulaire.
//
//  ---------------------------------------------------------------------------
//  TROIS TEMPS
//  ---------------------------------------------------------------------------
//  1. `creer()` envoie le filtre et le contexte de l'unité. Le serveur répond
//     dès que le projet est prêt côté fichiers, en donnant l'identifiant du
//     travail de packaging.
//  2. Le service interroge `GET /api/v1/jobs/<id>/` jusqu'à ce que ce travail
//     soit terminé — le packaging tourne dans un conteneur QGIS, il prend de
//     quelques secondes à quelques minutes.
//  3. Le projet est proposé au téléchargement dans QField, et le service nomme
//     le projet à ouvrir depuis l'écran « Projets ».
//
//  ---------------------------------------------------------------------------
//  LE DERNIER GESTE RESTE MANUEL
//  ---------------------------------------------------------------------------
//  Une version précédente fermait le projet ouvert, attendait le fichier sur le
//  disque et l'ouvrait par `iface.loadFile()`. Essayé sur l'appareil : ni le
//  retour à l'accueil ni l'ouverture automatique n'aboutissent. Ces étapes ont
//  donc été retirées, et ce service fait exactement ce que fait
//  `ServiceOuverture` après un packaging : il demande le téléchargement à
//  `QFieldCloudProjectsModel` — s'il l'atteint, ce qui n'est pas garanti, le
//  modèle ne faisant pas partie de l'API des greffons — puis signale le nom du
//  projet. Rien n'est fermé, rien n'est remplacé : le technicien garde son
//  projet à l'écran et ouvre le nouveau quand il le décide.
//
//  L'unité, elle, est créée dans tous les cas : c'est acquis dès la réponse du
//  serveur, avant même le packaging.
//
//  ---------------------------------------------------------------------------
//  CE QUE LE SERVEUR ATTEND
//  ---------------------------------------------------------------------------
//      {
//        "une_code_ident": "02-12777-IPE",
//        "type_ue": "Inventaire sur plan d'eau",
//        "criteres": [{ "mode": "region", "valeur": "02" },
//                     { "mode": "bassin", "valeur": "Saguenay" }],
//        "variables": { "code_region": "02", … }
//      }
//
//  `mode` vaut `region`, `lce`, `bassin` ou `emprise` — ce dernier portant
//  `wkt` et `bbox` au lieu de `valeur`. Les critères se **croisent** : seules
//  les unités qui les satisfont tous sont embarquées. C'est ce qui rend une
//  région utilisable comme critère : seule, elle dépasse ce que le serveur
//  accepte de préparer ; croisée avec un bassin, elle tient sur un appareil de
//  terrain.
//
//  L'identifiant et le type sont **envoyés à part**, bien qu'ils figurent aussi
//  dans `variables` : ce sont eux qui entrent dans la base métier, et ce qui y
//  entre ne doit pas dépendre d'un dictionnaire libre dont le serveur ignore
//  les clés inconnues.
//
//  Les variables, elles, sont celles que la fenêtre posait autrefois sur le
//  projet ouvert. Elles doivent voyager : le projet livré est un *autre*
//  projet, et c'est lui qui doit les porter.
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

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  property bool enCours: false

  // Dernier message d'avancement, affichable tel quel.
  property string etape: ""

  // Renseignés dès la réponse du serveur.
  property string projetId: ""
  property string projetNom: ""
  property string travailId: ""
  property string filtreLibelle: ""
  property int lignesEcrites: 0
  property int unitesEmbarquees: 0

  // L'unité telle que la base la porte après sa création : code, verrou,
  // détenteur, raison. Renseignée dès la réponse du serveur.
  property var uniteCreee: null

  // Le projet est prêt sur le serveur.
  signal pret(var infos)

  // Le projet reste à ouvrir à la main. Émis systématiquement après `pret` :
  // QField n'ouvre pas le projet lui-même (voir l'en-tête), que le
  // téléchargement ait pu être demandé ou non.
  // `paquetPret` distingue les deux façons dont on en arrive à une ouverture
  // manuelle : le packaging est terminé et le projet attend dans la liste, ou
  // l'attente a expiré et le serveur travaille encore. Les deux demandent le
  // même geste — aller dans « Projets » — mais pas au même moment, et
  // promettre un projet qui n'est pas là enverrait le technicien chercher
  // pour rien.
  signal ouvertureManuelle(string nomProjet, bool paquetPret)

  signal progression(string message)
  signal echec(string message)

  // ---------------------------------------------------------------------------
  //  Interne
  // ---------------------------------------------------------------------------
  // Une demande chasse la précédente : une réponse tardive ne doit pas relancer
  // un sondage abandonné.
  property int demandeCourante: 0

  // Le packaging d'un projet de saisie tient en quelques dizaines de secondes ;
  // la borne couvre un serveur chargé sans laisser tourner un sondage indéfini.
  property int intervalleSondageMs: 3000
  property int sondagesMax: 100
  property int sondagesFaits: 0

  Timer {
    id: minuterie

    interval: service.intervalleSondageMs
    repeat: true
    onTriggered: service.sonder()
  }

  // ===========================================================================
  //  API publique
  // ===========================================================================
  //  `unite`     { une_code_ident, type_ue } — l'unité à inscrire dans la base.
  //  `criteres`  [{ mode: "region"|"lce"|"bassin"|"emprise", valeur|wkt, bbox }]
  //              — croisés par le serveur ; un critère isolé est accepté tel
  //              quel.
  //  `variables` contexte de la saisie, posé en variables du projet livré.
  function creer(unite, criteres, variables) {
    if (!session) {
      echec(qsTr("Le service de création n'est pas relié à la session QFieldCloud."));
      return;
    }

    if (!unite || !unite.une_code_ident) {
      echec(qsTr("L'identifiant de la nouvelle unité est absent."));
      return;
    }

    const retenus = normaliser(criteres);

    if (retenus.length === 0) {
      echec(qsTr("Aucun critère de sélection des données à embarquer."));
      return;
    }

    annuler();

    const numero = ++demandeCourante;

    projetId = "";
    projetNom = "";
    travailId = "";
    filtreLibelle = "";
    lignesEcrites = 0;
    unitesEmbarquees = 0;
    uniteCreee = null;
    enCours = true;

    avancer(qsTr("Création de l'unité %1…").arg(unite.une_code_ident));

    session.appeler("POST", "/api/v1/ifa/formulaire/preparer/", corpsRequete(unite, retenus, variables), function (donnees) {
      if (numero !== service.demandeCourante)
        return;
      service.traiterPreparation(donnees);
    }, function (message) {
      if (numero !== service.demandeCourante)
        return;
      service.echouer(message);
    });
  }

  function annuler() {
    demandeCourante++;
    minuterie.stop();
    sondagesFaits = 0;
    enCours = false;
  }

  // Accepte aussi bien une liste de critères qu'un critère isolé.
  function normaliser(criteres) {
    if (!criteres)
      return [];

    if (criteres.mode !== undefined)
      return [criteres];

    const retenus = [];
    for (let i = 0; i < criteres.length; ++i) {
      if (criteres[i] && criteres[i].mode)
        retenus.push(criteres[i]);
    }

    return retenus;
  }

  function corpsRequete(unite, criteres, variables) {
    const envoyes = [];

    for (let i = 0; i < criteres.length; ++i) {
      envoyes.push(critereEnvoye(criteres[i]));
    }

    return {
      "une_code_ident": "" + unite.une_code_ident,
      "type_ue": "" + (unite.type_ue ? unite.type_ue : ""),
      "criteres": envoyes,
      "variables": variables ? variables : {}
    };
  }

  function critereEnvoye(critere) {
    if (critere.mode === "emprise") {
      const emprise = {
        "mode": "emprise",
        "wkt": critere.wkt
      };

      if (critere.bbox)
        emprise.bbox = critere.bbox;

      return emprise;
    }

    return {
      "mode": critere.mode,
      "valeur": "" + critere.valeur
    };
  }

  // ===========================================================================
  //  Préparation
  // ===========================================================================
  function traiterPreparation(donnees) {
    if (!donnees || !donnees.projet_id || !donnees.travail_id) {
      echouer(qsTr("Réponse du serveur illisible."));
      return;
    }

    projetId = "" + donnees.projet_id;
    projetNom = "" + (donnees.projet_nom !== undefined ? donnees.projet_nom : "");
    travailId = "" + donnees.travail_id;
    filtreLibelle = "" + (donnees.filtre !== undefined ? donnees.filtre : "");
    lignesEcrites = donnees.lignes !== undefined ? donnees.lignes : 0;
    unitesEmbarquees = donnees.unites !== undefined ? donnees.unites : 0;
    uniteCreee = donnees.unite !== undefined ? donnees.unite : null;

    // L'unité existe désormais dans la base et personne d'autre ne peut la
    // prendre : c'est acquis, même si le packaging échouait ensuite.
    if (uniteCreee && uniteCreee["une_code_ident"])
      avancer(qsTr("Unité %1 créée et verrouillée — packaging en cours…").arg(uniteCreee["une_code_ident"]));
    else
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
      // Le packaging se poursuit sur le serveur : l'attente cesse, pas le
      // travail. Le projet finira par être disponible sous son nom.
      terminer();
      ouvertureManuelle(projetNom, false);
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
      echouer(qsTr("Le packaging du projet %1 a échoué sur le serveur.").arg(projetNom));
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
    terminer();

    pret({
      "projet_id": projetId,
      "projet_nom": projetNom,
      "filtre": filtreLibelle,
      "lignes": lignesEcrites,
      "unites": unitesEmbarquees,
      "unite": uniteCreee
    });

    // Le téléchargement est demandé si QField laisse l'atteindre, mais rien
    // n'en dépend : le projet est signalé dans tous les cas, et c'est le
    // technicien qui l'ouvre.
    telecharger(projetId);

    ouvertureManuelle(projetNom, true);
  }

  // Demande à QField de rapatrier le projet.
  //
  // `CloudProjectsModel` ne fait pas partie de l'API des greffons : les noms
  // essayés ici sont ceux qu'emploie l'application, et une version qui ne les
  // expose pas fait simplement retomber sur un téléchargement manuel depuis
  // l'écran « Projets ». Même mécanique que `ServiceOuverture.telecharger()`.
  function telecharger(identifiant) {
    const modele = resoudreModeleProjets();

    if (!modele) {
      iface.logMessage("[IFA] modele des projets infonuagiques inatteignable : telechargement manuel");
      return false;
    }

    try {
      if (typeof modele.refreshProjectsList === "function")
        modele.refreshProjectsList();

      if (typeof modele.downloadProject === "function") {
        modele.downloadProject(identifiant);
        return true;
      }

      if (typeof modele.projectDownload === "function") {
        modele.projectDownload(identifiant);
        return true;
      }
    } catch (e) {
      iface.logMessage("[IFA] telechargement automatique impossible : " + e);
    }

    return false;
  }

  function resoudreModeleProjets() {
    const noms = ["cloudProjectsModel", "CloudProjectsModel", "cloudProjects"];

    for (let i = 0; i < noms.length; ++i) {
      try {
        const objet = iface.findItemByObjectName(noms[i]);
        if (objet)
          return objet;
      } catch (e) {
        // Nom inconnu de cette version de QField : on essaie le suivant.
      }
    }

    return null;
  }

  // ===========================================================================
  //  Utilitaires
  // ===========================================================================
  function avancer(message) {
    etape = message;
    progression(message);
  }

  function terminer() {
    minuterie.stop();
    enCours = false;
    etape = "";
  }

  function echouer(message) {
    terminer();
    echec(message);
  }
}
