// =============================================================================
//  ServiceUE — accès aux unités d'échantillonnage (SIMULATION)
// =============================================================================
//  ⚠️ Ce fichier est un BOUCHON. Le point d'accès QFieldCloud n'existe pas
//  encore : les résultats sont fabriqués localement pour permettre de
//  concevoir et d'essayer l'interface dès maintenant.
//
//  ---------------------------------------------------------------------------
//  QUAND LE BACKEND SERA EN PLACE
//  ---------------------------------------------------------------------------
//  Seul CE fichier change ; ni FenetreConsulterUE ni TableauUE n'ont à bouger.
//  Remplacer le corps de `rechercher()` par un appel HTTP, en conservant le
//  contrat ci-dessous :
//
//    const requete = iface.createHttpRequest();
//    requete.open("POST", urlServeur + "/api/v1/ifa/unites/");
//    requete.setRequestHeader("Content-Type", "application/json");
//    requete.setRequestHeader("Authorization", "Token " + jeton);
//    // ⚠️ un User-Agent commençant par « qfield| » ferait expirer le jeton de
//    //    QField lui-même (AuthToken.single_token_clients côté serveur).
//    requete.setRequestHeader("User-Agent", "sdk|ifa-plugin/1.0");
//    requete.onreadystatechange = function () { … resultats(lignes) … };
//    requete.send(JSON.stringify(filtre));
//
//  ---------------------------------------------------------------------------
//  CONTRAT
//  ---------------------------------------------------------------------------
//  Entrée — `rechercher(filtre)` où `filtre` vaut :
//      { mode: "region",  valeur: "02" }
//      { mode: "lce",     valeur: "12777" }
//      { mode: "code",    valeur: "02-12777-IPE" }
//      { mode: "emprise", wkt: "POLYGON((…))", bbox: [xmin, ymin, xmax, ymax] }
//
//  Sortie — signal `resultats(lignes)`, une ligne par unité, reprenant les
//  colonnes de la table `unite_echan` :
//      {
//        une_code_ident:       "02-12777-IPE",
//        tue_code_ident:       "f0758571-…",      // UUID du type
//        tue_nom:              "Inventaire sur plan d'eau",
//        une_ind_verro:        "N",               // "O" = verrouillée
//        une_nom_propr_verro:  "",                // détenteur du verrou
//        une_date_creat:       "2009-10-21T14:52:56Z",
//        une_code_utili_creat: "ifa0t2",
//        une_date_maj:         "2025-04-03T12:31:07Z",
//        une_code_utili_maj:   "kamdo1"
//      }
//
//  En cas d'échec : signal `echec(message)`.
// =============================================================================

import QtQuick

import org.qfield

QtObject {
  id: service

  // ---------------------------------------------------------------------------
  //  API publique
  // ---------------------------------------------------------------------------
  // Laisser à true tant que le point d'accès serveur n'est pas déployé.
  property bool simulation: true

  property bool enCours: false

  // Listes de référence (Referentiels), pour que les types simulés
  // correspondent à ceux du reste du plugin.
  property var referentiels: null

  signal resultats(var lignes)
  signal echec(string message)

  // Filtre de la requête en cours.
  property var filtreCourant: null

  // Latence simulée, pour vérifier que l'écran d'attente se comporte bien.
  property Timer minuterie: Timer {
    interval: 700
    repeat: false
    onTriggered: service.repondreSimulation()
  }

  function rechercher(filtre) {
    filtreCourant = filtre;
    enCours = true;

    if (simulation) {
      minuterie.restart();
      return;
    }

    // À implémenter avec le point d'accès réel (voir l'en-tête du fichier).
    enCours = false;
    echec(qsTr("Le service d'interrogation des UE n'est pas encore déployé."));
  }

  function annuler() {
    minuterie.stop();
    enCours = false;
  }

  // ===========================================================================
  //  SIMULATION — tout ce qui suit disparaîtra avec le bouchon
  // ===========================================================================

  // Générateur pseudo-aléatoire à graine : deux recherches identiques rendent
  // le même jeu de données, ce qui rend les essais reproductibles.
  property var graine: 1

  function alea() {
    // Suite congruentielle linéaire (constantes de Numerical Recipes).
    graine = (graine * 1664525 + 1013904223) % 4294967296;
    return graine / 4294967296;
  }

  function aleaEntier(min, max) {
    return min + Math.floor(alea() * (max - min + 1));
  }

  function choisir(liste) {
    return liste[aleaEntier(0, liste.length - 1)];
  }

  // Codes d'utilisateur relevés dans les données réelles.
  readonly property var utilisateurs: ["ifa0t2", "rioel2", "brach1", "rouel2", "bouau4", "milty1", "kamdo1", "patje2", "trela3", "gagnm5"]

  function horodatage(anneeMin, anneeMax) {
    const annee = aleaEntier(anneeMin, anneeMax);
    const mois = aleaEntier(1, 12);
    const jour = aleaEntier(1, 28);
    const heure = aleaEntier(6, 20);
    const minute = aleaEntier(0, 59);
    const seconde = aleaEntier(0, 59);

    function deuxChiffres(n) {
      return n < 10 ? "0" + n : "" + n;
    }

    return annee + "-" + deuxChiffres(mois) + "-" + deuxChiffres(jour) + "T" + deuxChiffres(heure) + ":" + deuxChiffres(minute) + ":" + deuxChiffres(seconde) + "Z";
  }

  // Types disponibles, repris de Referentiels pour rester cohérents avec le
  // formulaire de création.
  function typesDisponibles() {
    if (referentiels && referentiels.typesUe && referentiels.typesUe.length > 0)
      return referentiels.typesUe;
    return [
      {
        "code": "IPE",
        "nom": "Inventaire sur plan d'eau"
      },
      {
        "code": "OG",
        "nom": "Observation générale"
      }
    ];
  }

  function fabriquerUnite(codeRegion, noLce, type) {
    const dateCreation = horodatage(2009, 2023);
    const dateMaj = horodatage(2024, 2026);

    // Environ une unité sur huit est verrouillée — les données réelles en
    // comptent bien moins, mais il faut pouvoir voir le cas à l'écran.
    const verrouillee = alea() < 0.13;
    const detenteur = verrouillee ? choisir(utilisateurs) : "";

    return {
      "une_code_ident": codeRegion + "-" + noLce + "-" + type.code,
      "tue_code_ident": "",
      "tue_nom": type.nom,
      "une_ind_verro": verrouillee ? "O" : "N",
      "une_nom_propr_verro": detenteur,
      "une_date_creat": dateCreation,
      "une_code_utili_creat": choisir(utilisateurs),
      "une_date_maj": dateMaj,
      "une_code_utili_maj": choisir(utilisateurs)
    };
  }

  function repondreSimulation() {
    enCours = false;

    const filtre = filtreCourant ? filtreCourant : {
      "mode": "region",
      "valeur": "02"
    };

    // Graine dérivée du filtre : même filtre, même résultat.
    let empreinte = 7;
    const texte = filtre.mode + "|" + (filtre.valeur ? filtre.valeur : "") + "|" + (filtre.wkt ? filtre.wkt.length : 0);
    for (let i = 0; i < texte.length; ++i) {
      empreinte = (empreinte * 31 + texte.charCodeAt(i)) % 4294967296;
    }
    graine = empreinte + 1;

    const types = typesDisponibles();
    const lignes = [];

    if (filtre.mode === "code") {
      // Recherche par code exact : la moitié des codes inventés sont
      // introuvables, pour que l'écran « aucun résultat » soit atteignable.
      const code = ("" + filtre.valeur).trim().toUpperCase();
      const morceaux = code.split("-");

      if (morceaux.length === 3 && alea() < 0.75) {
        let type = types[0];
        for (let t = 0; t < types.length; ++t) {
          if (types[t].code === morceaux[2])
            type = types[t];
        }
        const unite = fabriquerUnite(morceaux[0], morceaux[1], type);
        unite.une_code_ident = code;
        lignes.push(unite);
      }

      resultats(lignes);
      return;
    }

    if (filtre.mode === "lce") {
      // Un même plan d'eau porte en général plusieurs types d'unités.
      const noLce = ("" + filtre.valeur).trim();
      const region = ["02", "07", "09", "11"][aleaEntier(0, 3)];
      const nombre = aleaEntier(2, 5);

      for (let i = 0; i < nombre && i < types.length; ++i) {
        lignes.push(fabriquerUnite(region, noLce, types[i]));
      }

      resultats(lignes);
      return;
    }

    // Région ou emprise : un lot d'unités réparties sur plusieurs plans d'eau.
    const region = filtre.mode === "region" && filtre.valeur ? ("" + filtre.valeur) : ["02", "07", "09"][aleaEntier(0, 2)];
    const nombre = filtre.mode === "emprise" ? aleaEntier(6, 14) : aleaEntier(12, 24);

    for (let i = 0; i < nombre; ++i) {
      const noLce = "" + aleaEntier(10000, 99999);
      lignes.push(fabriquerUnite(region, noLce, choisir(types)));
    }

    lignes.sort(function (a, b) {
      return a["une_code_ident"] < b["une_code_ident"] ? -1 : 1;
    });

    resultats(lignes);
  }
}
