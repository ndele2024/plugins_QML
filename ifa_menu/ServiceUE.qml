// =============================================================================
//  ServiceUE — recherche des unités d'échantillonnage sur le serveur
// =============================================================================
//  Interroge le point d'accès QFieldCloud
//
//      POST /api/v1/ifa/unites/recherche/
//
//  ajouté au serveur par l'application Django `qfieldcloud.ifa`. Celle-ci lit
//  la base métier du ministère (schéma `ifa_data`) en lecture seule ; QField
//  n'a donc jamais besoin d'un accès direct à PostgreSQL.
//
//  L'authentification est déléguée à `SessionCloud` (voir ce fichier pour la
//  raison pour laquelle le plugin obtient son propre jeton).
//
//  ---------------------------------------------------------------------------
//  CONTRAT
//  ---------------------------------------------------------------------------
//  Entrée — `rechercher(criteres)`, une liste de critères :
//      [{ mode: "region",  valeur: "02" },
//       { mode: "lce",     valeur: "12777" },
//       { mode: "bassin",  valeur: "Saguenay" },
//       { mode: "code",    valeur: "02-12777-IPE" },
//       { mode: "emprise", wkt: "POLYGON((…))", bbox: [xmin, ymin, xmax, ymax] }]
//
//  Les critères se **croisent** : le serveur ne rend que les unités qui les
//  satisfont tous. Chaque critère ajouté resserre la liste — c'est ce qu'on
//  attend d'un formulaire de recherche, et c'est ce qui rend le décompte
//  lisible. Un même mode n'est accepté qu'une fois : deux régions croisées ne
//  rendraient jamais rien.
//
//  Un critère isolé (l'objet, hors de toute liste) est accepté tel quel : les
//  fenêtres n'ont pas toutes à savoir qu'elles peuvent en envoyer plusieurs.
//
//  Sortie — signal `resultats(lignes)`, une ligne par unité :
//      {
//        une_code_ident:       "02-12777-IPE",
//        tue_code_ident:       "f0758571-…",      // UUID du type
//        tue_nom:              "Inventaire sur plan d'eau",
//        une_ind_verro:        "N",               // "O" = verrouillée
//        une_nom_propr_verro:  "",                // détenteur du verrou
//        une_date_verro:       "",
//        une_raiso_verro:      "",
//        une_date_creat:       "2009-10-21T14:52:56",
//        une_code_utili_creat: "ifa0t2",
//        une_date_maj:         "2025-04-03T12:31:07",
//        une_code_utili_maj:   "kamdo1",
//        rad_no:               "02",              // région du projet
//        ing_no_plan_eau:      "12777",
//        ing_nom_plan_eau:     "ILETS, LAC DES",
//        ing_nom_bassi:        "SAGUENAY",        // bassin versant
//        latitude:             48.196709,         // null si non localisée
//        longitude:            -71.233353
//      }
//
//  En cas d'échec : signal `echec(message)`, message déjà rédigé pour
//  l'affichage.
//
//  ---------------------------------------------------------------------------
//  PAGINATION
//  ---------------------------------------------------------------------------
//  `unite_echan` compte environ 142 000 lignes et une recherche par région en
//  renvoie plus de 12 000 : le serveur ne rend qu'une page à la fois. `total`
//  porte le décompte complet, `tronque` dit s'il reste des unités, et
//  `pageSuivante()` demande la suite — que le signal `resultats` rend cumulée
//  avec les pages déjà reçues, pour que la fenêtre n'ait rien à recoller.
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

  // Nombre d'unités correspondant au filtre, toutes pages confondues.
  property int total: 0

  // Vrai s'il reste des unités au-delà de celles déjà reçues.
  property bool tronque: false

  readonly property int nombreRecu: unitesRecues.length

  // Taille d'une page. 200 lignes remplissent largement un écran de terrain
  // sans faire peser plusieurs mégaoctets sur une liaison mobile.
  property int taillePage: 200

  signal resultats(var lignes)
  signal echec(string message)

  // ---------------------------------------------------------------------------
  //  Interne
  // ---------------------------------------------------------------------------
  // Les critères de la recherche en cours, toujours sous forme de liste.
  property var criteresCourants: []
  property var unitesRecues: []

  // Numéro de la recherche en cours. Une réponse dont le numéro ne correspond
  // plus est ignorée : sans cela, une première recherche lente écraserait le
  // résultat d'une seconde, lancée entre-temps.
  property int rechercheCourante: 0

  // ===========================================================================
  //  API publique
  // ===========================================================================
  function rechercher(criteres) {
    criteresCourants = normaliser(criteres);
    unitesRecues = [];
    total = 0;
    tronque = false;
    rechercheCourante++;

    if (criteresCourants.length === 0) {
      echec(qsTr("Aucun critère de recherche n'a été retenu."));
      return;
    }

    interroger(0);
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

  // Demande la page suivante et cumule les résultats.
  function pageSuivante() {
    if (enCours || !tronque || criteresCourants.length === 0)
      return;

    interroger(unitesRecues.length);
  }

  function annuler() {
    // La requête HTTP suit son cours, mais sa réponse ne sera plus retenue.
    rechercheCourante++;
    enCours = false;
  }

  // ===========================================================================
  //  Interrogation du serveur
  // ===========================================================================
  function interroger(decalage) {
    if (!session) {
      echec(qsTr("Le service d'interrogation n'est pas relié à la session QFieldCloud."));
      return;
    }

    const numero = rechercheCourante;
    enCours = true;

    session.appeler("POST", "/api/v1/ifa/unites/recherche/", corpsRequete(decalage), function (donnees) {
      if (numero !== service.rechercheCourante)
        return;
      service.enCours = false;
      service.traiterReponse(donnees, decalage);
    }, function (message) {
      if (numero !== service.rechercheCourante)
        return;
      service.enCours = false;
      service.echec(message);
    });
  }

  function corpsRequete(decalage) {
    const envoyes = [];

    for (let i = 0; i < criteresCourants.length; ++i) {
      envoyes.push(critereEnvoye(criteresCourants[i]));
    }

    return {
      "criteres": envoyes,
      "limite": taillePage,
      "decalage": decalage
    };
  }

  // Un critère mis à la forme attendue par le serveur. L'emprise porte son
  // polygone et sa boîte englobante ; tous les autres modes portent une valeur.
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

  function traiterReponse(donnees, decalage) {
    if (!donnees || donnees.resultats === undefined) {
      echec(qsTr("Réponse du serveur illisible."));
      return;
    }

    // Une page qui n'est pas celle attendue (double clic, réponse tardive)
    // décalerait la liste : on la laisse tomber plutôt que de l'insérer.
    if (decalage !== unitesRecues.length)
      return;

    const cumul = unitesRecues.slice();
    for (let i = 0; i < donnees.resultats.length; ++i) {
      cumul.push(donnees.resultats[i]);
    }

    unitesRecues = cumul;
    total = donnees.total !== undefined ? donnees.total : cumul.length;
    tronque = donnees.tronque === true && donnees.resultats.length > 0;

    resultats(cumul);
  }
}
