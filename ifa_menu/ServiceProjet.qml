// =============================================================================
//  ServiceProjet — inscription d'un projet de sondage dans la base IFA
// =============================================================================
//  Interroge deux points d'accès QFieldCloud, servis par l'application Django
//  `qfieldcloud.ifa` (voir `projet_sonda.py`) :
//
//      GET  /api/v1/ifa/types-ue/                    les types d'UE du référentiel
//      POST /api/v1/ifa/projets-sondage/             le projet et ses types d'UE
//      GET  /api/v1/ifa/projets-sondage/types-ue/    les types d'un projet
//      GET  /api/v1/ifa/projets-sondage/             tous les projets, et les droits
//      GET  /api/v1/ifa/projets-sondage/<id>/        un projet, ses types, ses droits
//      POST /api/v1/ifa/projets-sondage/<id>/modifier/
//      POST /api/v1/ifa/projets-sondage/<id>/supprimer/   (mot de passe exigé)
//
//  Le serveur écrit le projet dans `ifa_data.proje_sonda` et ses types dans
//  `ifa_data.proje_type_unite_echan`, dans une même transaction. Rien d'autre :
//  pas de projet QFieldCloud à préparer, pas de packaging à attendre.
//
//  Les types viennent du serveur, pas de `Referentiels.typesUe` : cette liste
//  codée en dur en omet plusieurs (ADNe, Enregistrement saumon atlantique…), et
//  l'association se fait par identifiant (`tue_code_ident`), que seul le
//  serveur connaît.
//
//  ---------------------------------------------------------------------------
//  CONTRAT
//  ---------------------------------------------------------------------------
//  Entrée — `creer(projet)` :
//      {
//        pro_no:              "09-OG",          // unique, 20 caractères max
//        pro_nom:             "Observations générales",
//        pro_an:              2026,
//        rad_no:              "09",
//        pro_code_statu:      "El" | "Pr",
//        pro_ind_inven_norma: false,
//        pro_descr:           "",               // facultatif
//        pro_com:             "",               // facultatif
//        types_ue: [                            // au moins un
//          { tue_code_ident: "f0758571-…", nb_impla_plani: 12, nb_remes_plani: 2 }
//        ]
//      }
//  L'identifiant (UUID), les dates, l'utilisateur et la version de type sont
//  fixés par le serveur : ils ne voyagent pas.
//
//  Sortie — signal `cree(projet)`, la ligne telle que la base la porte, sans
//  aucun `null` dans les textes, et `projet.types_ue` : les types écrits, avec
//  leur libellé et leurs nombres planifiés (obligatoires : au moins une
//  implantation, zéro remesurage ou plus).
//
//  Types — `chargerTypes()` remplit `types` ([{ tue_code_ident, tue_nom,
//  tue_descr }], triés par libellé) et émet `typesCharges()`, ou `echecTypes`.
//
//  Types d'un projet — `chargerTypesDuProjet(proNo)` émet
//  `typesDuProjetRecus(proNo, types)` ([{ tue_code_ident, tue_nom,
//  nb_impla_plani, nb_remes_plani }], vide si le projet n'en prévoit aucun), ou
//  `echecTypesDuProjet(proNo, message, statut)`. Une demande chasse la
//  précédente : changer de projet pendant l'attente n'affiche jamais les types
//  de l'ancien. Utilisé par « Créer une UE ».
//
//  Gestion — « Modifier / Afficher / Supprimer un projet » :
//    lister()                  → listeRecue({ admin, utilisateur, projets })
//    lire(id)                  → projetLu(projet)
//    modifier(id, changements) → projetModifie(projet)
//    supprimer(id, motDePasse) → projetSupprime(resultat)
//  Chaque projet rendu porte `droits` ({ admin, createur, utilise, nb_unites,
//  modifiable, champs_modifiables, raison_modification, supprimable,
//  raison_suppression }) : la fenêtre s'en sert pour se présenter, le serveur
//  les revérifie de toute façon. Un échec émet
//  `echecGestion(operation, message, statut)`, `operation` valant "lister",
//  "lire", "modifier" ou "supprimer".
//
//  Le mot de passe de la suppression ne fait que passer : il n'est ni gardé,
//  ni journalisé. Un mot de passe faux répond 403 — pas 401, qui ferait
//  redemander un jeton à `SessionCloud`.
//
//  En cas d'échec : signal `echec(message, statut)`. Le message est celui du
//  serveur, rédigé pour être affiché tel quel — un n° déjà pris (409) nomme le
//  projet qui le porte.
// =============================================================================

import QtQuick

import org.qfield

QtObject {
  id: service

  // ---------------------------------------------------------------------------
  //  Dépendances injectées
  // ---------------------------------------------------------------------------
  property var session: null

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  property bool enCours: false

  property var types: []
  property bool typesEnCours: false

  signal cree(var projet)
  signal echec(string message, int statut)
  signal typesCharges
  signal echecTypes(string message)
  signal typesDuProjetRecus(string proNo, var types)
  signal echecTypesDuProjet(string proNo, string message, int statut)
  signal listeRecue(var donnees)
  signal projetLu(var projet)
  signal projetModifie(var projet)
  signal projetSupprime(var resultat)
  signal echecGestion(string operation, string message, int statut)

  // L'opération de gestion en cours ("lister", "lire", "modifier",
  // "supprimer"), ou "".
  property string gestionEnCours: ""

  property bool typesDuProjetEnCours: false

  // ---------------------------------------------------------------------------
  //  Interne
  // ---------------------------------------------------------------------------
  // Une réponse arrivée après `annuler()` ne doit plus rien déclencher.
  property int demandeCourante: 0
  property int demandeTypesDuProjet: 0
  property int demandeGestion: 0

  // ===========================================================================
  //  API publique
  // ===========================================================================
  function creer(projet) {
    if (!session) {
      echec(qsTr("Le service de création de projet n'est pas relié à la session QFieldCloud."), 0);
      return;
    }

    const numero = ++demandeCourante;
    enCours = true;

    session.appeler("POST", "/api/v1/ifa/projets-sondage/", projet, function (donnees) {
      if (numero !== service.demandeCourante)
        return;
      service.enCours = false;

      if (!donnees || !donnees.pro_code_ident) {
        service.echec(qsTr("Réponse du serveur illisible."), 0);
        return;
      }

      service.cree(donnees);
    }, function (message, statut) {
      if (numero !== service.demandeCourante)
        return;
      service.enCours = false;
      service.echec(message, statut ? statut : 0);
    });
  }

  function chargerTypes() {
    if (!session) {
      echecTypes(qsTr("Le service de création de projet n'est pas relié à la session QFieldCloud."));
      return;
    }

    typesEnCours = true;

    session.appeler("GET", "/api/v1/ifa/types-ue/", null, function (donnees) {
      service.typesEnCours = false;

      if (!donnees || !Array.isArray(donnees.types)) {
        service.echecTypes(qsTr("Liste des types d'UE illisible."));
        return;
      }

      service.types = donnees.types;
      service.typesCharges();
    }, function (message) {
      service.typesEnCours = false;
      service.echecTypes(message);
    });
  }

  function chargerTypesDuProjet(proNo) {
    const numero = ++demandeTypesDuProjet;

    if (!session) {
      echecTypesDuProjet(proNo, qsTr("session QFieldCloud absente"), 0);
      return;
    }

    typesDuProjetEnCours = true;

    // Le n° voyage en paramètre de requête : il est saisi librement et peut
    // contenir des espaces, voire une barre oblique.
    session.appeler("GET", "/api/v1/ifa/projets-sondage/types-ue/?pro_no=" + encodeURIComponent(proNo), null, function (donnees) {
      if (numero !== service.demandeTypesDuProjet)
        return;
      service.typesDuProjetEnCours = false;

      if (!donnees || !Array.isArray(donnees.types)) {
        service.echecTypesDuProjet(proNo, qsTr("réponse illisible"), 0);
        return;
      }

      service.typesDuProjetRecus(proNo, donnees.types);
    }, function (message, statut) {
      if (numero !== service.demandeTypesDuProjet)
        return;
      service.typesDuProjetEnCours = false;
      service.echecTypesDuProjet(proNo, message, statut ? statut : 0);
    });
  }

  // ---- Gestion ---------------------------------------------------------------
  function lister() {
    gerer("lister", "GET", "/api/v1/ifa/projets-sondage/", null, function (donnees) {
      if (!donnees || !Array.isArray(donnees.projets))
        return false;
      service.listeRecue(donnees);
      return true;
    });
  }

  function lire(code) {
    gerer("lire", "GET", cheminProjet(code), null, function (donnees) {
      if (!donnees || !donnees.pro_code_ident)
        return false;
      service.projetLu(donnees);
      return true;
    });
  }

  function modifier(code, changements) {
    gerer("modifier", "POST", cheminProjet(code) + "modifier/", changements, function (donnees) {
      if (!donnees || !donnees.pro_code_ident)
        return false;
      service.projetModifie(donnees);
      return true;
    });
  }

  function supprimer(code, motDePasse) {
    gerer("supprimer", "POST", cheminProjet(code) + "supprimer/", {
      "mot_de_passe": motDePasse
    }, function (donnees) {
      if (!donnees || donnees.supprime !== true)
        return false;
      service.projetSupprime(donnees);
      return true;
    });
  }

  function cheminProjet(code) {
    return "/api/v1/ifa/projets-sondage/" + encodeURIComponent(code) + "/";
  }

  // Une seule opération de gestion à la fois : la dernière demandée l'emporte,
  // la réponse d'une précédente est ignorée.
  function gerer(operation, methode, chemin, corps, traiter) {
    const numero = ++demandeGestion;

    if (!session) {
      echecGestion(operation, qsTr("Le service des projets n'est pas relié à la session QFieldCloud."), 0);
      return;
    }

    gestionEnCours = operation;

    session.appeler(methode, chemin, corps, function (donnees) {
      if (numero !== service.demandeGestion)
        return;
      service.gestionEnCours = "";
      if (!traiter(donnees))
        service.echecGestion(operation, qsTr("Réponse du serveur illisible."), 0);
    }, function (message, statut) {
      if (numero !== service.demandeGestion)
        return;
      service.gestionEnCours = "";
      service.echecGestion(operation, message, statut ? statut : 0);
    });
  }

  function oublierGestion() {
    demandeGestion++;
    gestionEnCours = "";
  }

  // Abandonne l'attente des types d'un projet : la réponse sera ignorée.
  function oublierTypesDuProjet() {
    demandeTypesDuProjet++;
    typesDuProjetEnCours = false;
  }

  // La requête partie n'est pas rappelée : si le serveur l'a reçue, le projet
  // sera créé. Seul le suivi s'arrête.
  function annuler() {
    demandeCourante++;
    enCours = false;
  }
}
