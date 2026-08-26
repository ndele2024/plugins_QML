// =============================================================================
//  Referentiels — données et accès aux couches partagés par les fenêtres
// =============================================================================
//  Une seule instance est créée dans main.qml, puis injectée dans chaque
//  fenêtre via sa propriété `referentiels`. Centraliser ici les listes de
//  référence et les accès aux couches évite de les redupliquer dans chaque
//  formulaire, et garde les fenêtres concentrées sur l'interface.
//
//  ⚠️ Toutes les fonctions qui touchent aux couches sont défensives : elles
//  renvoient une valeur neutre si la couche est absente du projet courant.
//  Le plugin doit rester utilisable même sur un projet incomplet.
//
//  TODO (étape suivante) : remplacer `regions` et `typesUe` codés en dur par
//  une lecture des couches de référence (ifa_referentiels) ou par un appel aux
//  points d'accès QFieldCloud.
// =============================================================================

import QtQuick

import org.qfield
import org.qgis

QtObject {
  id: refs

  // ---------------------------------------------------------------------------
  //  Listes de référence
  // ---------------------------------------------------------------------------
  readonly property var regions: [
    {
      code: "01",
      nom: "01 - Bas-Saint-Laurent"
    },
    {
      code: "02",
      nom: "02 - Saguenay–Lac-Saint-Jean"
    },
    {
      code: "03",
      nom: "03 - Capitale-Nationale"
    },
    {
      code: "04",
      nom: "04 - Mauricie"
    },
    {
      code: "05",
      nom: "05 - Estrie"
    },
    {
      code: "06",
      nom: "06 - Montréal"
    },
    {
      code: "07",
      nom: "07 - Outaouais"
    },
    {
      code: "08",
      nom: "08 - Abitibi-Témiscamingue"
    },
    {
      code: "09",
      nom: "09 - Côte-Nord"
    },
    {
      code: "10",
      nom: "10 - Nord-du-Québec"
    },
    {
      code: "11",
      nom: "11 - Gaspésie–Îles-de-la-Madeleine"
    },
    {
      code: "12",
      nom: "12 - Chaudière-Appalaches"
    },
    {
      code: "13",
      nom: "13 - Laval"
    },
    {
      code: "14",
      nom: "14 - Lanaudière"
    },
    {
      code: "15",
      nom: "15 - Laurentides"
    },
    {
      code: "16",
      nom: "16 - Montérégie"
    },
    {
      code: "17",
      nom: "17 - Centre-du-Québec"
    }
  ]

  readonly property var typesUe: [
    {
      code: "AME",
      nom: "Aménagement"
    },
    {
      code: "DEC",
      nom: "Déclaration de spécimens"
    },
    {
      code: "ONMY",
      nom: "Enregistrement de la truite arc-en-ciel"
    },
    {
      code: "ENS",
      nom: "Ensemencement"
    },
    {
      code: "NORD",
      nom: "Inventaire du Nord"
    },
    {
      code: "ICE",
      nom: "Inventaire en cours d'eau"
    },
    {
      code: "FSL",
      nom: "Inventaire sur le fleuve"
    },
    {
      code: "IPE",
      nom: "Inventaire sur plan d'eau"
    },
    {
      code: "OG",
      nom: "Observation générale"
    },
    {
      code: "PS",
      nom: "Pêche sportive"
    },
    {
      code: "ANRO",
      nom: "Réseau de suivi ANRO"
    },
    {
      code: "MOSA",
      nom: "Réseau de suivi MOSA"
    },
    {
      code: "RIPE",
      nom: "Réseau d'inventaire des poissons de l'Estuaire"
    }
  ]

  // ---------------------------------------------------------------------------
  //  Projets de sondage (lus dans la couche « proje_sonda » du projet courant)
  // ---------------------------------------------------------------------------
  property var projets: []
  property var projetsParRegion: ({})
  property bool projetsCharges: false

  // ---------------------------------------------------------------------------
  //  Accès aux couches
  // ---------------------------------------------------------------------------
  // Renvoie la première couche portant ce nom, ou null si elle est absente.
  // Toujours passer par cette fonction : `mapLayersByName(nom)[0]` lève une
  // erreur quand la couche n'existe pas.
  function couche(nom) {
    if (typeof qgisProject === "undefined" || !qgisProject)
      return null;
    const trouvees = qgisProject.mapLayersByName(nom);
    return trouvees && trouvees.length > 0 ? trouvees[0] : null;
  }

  // Charge (ou recharge) la liste des projets en production, triés du plus
  // récent au plus ancien, et la répartition par région administrative.
  // Renvoie true si la couche a été trouvée.
  function chargerProjets() {
    projets = [];
    projetsParRegion = ({});
    projetsCharges = false;

    const coucheProjets = couche("proje_sonda");
    if (!coucheProjets) {
      iface.logMessage("[IFA] couche « proje_sonda » absente : liste des projets vide");
      return false;
    }

    const champs = ["pro_no", "pro_nom", "rad_no", "pro_an"];
    const liste = [];

    const it = LayerUtils.createFeatureIteratorFromExpression(coucheProjets, "pro_code_statu = 'Pr'");
    while (it.hasNext()) {
      const entite = it.next();
      const projet = {};
      for (let i = 0; i < champs.length; ++i) {
        projet[champs[i]] = entite.attribute(champs[i]);
      }
      liste.push(projet);
    }
    it.close();

    liste.sort(function (a, b) {
      return b["pro_an"] - a["pro_an"];
    });

    const parRegion = {};
    for (let r = 0; r < regions.length; ++r) {
      const codeRegion = regions[r].code;
      parRegion[codeRegion] = liste.filter(function (p) {
        return p["rad_no"] === codeRegion;
      });
    }

    projets = liste;
    projetsParRegion = parRegion;
    projetsCharges = true;
    return true;
  }

  // Projets d'une région donnée ; tous les projets si aucune région n'est
  // sélectionnée.
  function projetsDeLaRegion(codeRegion) {
    if (!codeRegion)
      return projets;
    return projetsParRegion[codeRegion] ? projetsParRegion[codeRegion] : [];
  }

  // ---------------------------------------------------------------------------
  //  Recherche d'un plan d'eau par son numéro officiel (code LCE)
  // ---------------------------------------------------------------------------
  // Renvoie { coucheDisponible, trouve, nom, mrc }.
  function rechercherLce(noLce) {
    const resultat = {
      "coucheDisponible": false,
      "trouve": false,
      "nom": "",
      "mrc": ""
    };

    // Le champ n'accepte que des chiffres, mais on filtre malgré tout : la
    // valeur part dans une expression QGIS.
    const numero = ("" + noLce).replace(/[^0-9]/g, "");
    if (numero === "")
      return resultat;

    const coucheLce = couche("LCE");
    if (!coucheLce)
      return resultat;

    resultat.coucheDisponible = true;

    const it = LayerUtils.createFeatureIteratorFromExpression(coucheLce, "NO_LCE = '" + numero + "'");
    if (it.hasNext()) {
      const entite = it.next();
      resultat.trouve = true;

      // Les noms sont stockés en forme inversée (« Vert, Lac ») : on rétablit
      // l'ordre naturel pour l'affichage.
      const nom = "" + entite.attribute("NOM_LCE");
      resultat.nom = nom.split(", ").reverse().join(" ");
      resultat.mrc = "" + entite.attribute("NOM_MRC");
    }
    it.close();

    return resultat;
  }

  // ---------------------------------------------------------------------------
  //  Région administrative déduite de la position GPS
  // ---------------------------------------------------------------------------
  // Renvoie le code de région (« 02 ») ou une chaîne vide si la position n'est
  // pas disponible ou si la couche « regio_s » est absente.
  function regionParGps() {
    const source = iface.findItemByObjectName("positionSource");
    if (!source || !source.active)
      return "";

    const position = source.positionInformation;
    if (!position || !position.latitudeValid || !position.longitudeValid)
      return "";

    const coucheRegions = couche("regio_s");
    if (!coucheRegions)
      return "";

    const expression = "intersects(@geometry, make_point(" + position.longitude + ", " + position.latitude + "))";
    const it = LayerUtils.createFeatureIteratorFromExpression(coucheRegions, expression);

    let code = "";
    if (it.hasNext()) {
      code = "" + it.next().attribute("RES_CO_REG");
    }
    it.close();

    return code;
  }

  // ---------------------------------------------------------------------------
  //  Variables de projet
  // ---------------------------------------------------------------------------
  function variableProjet(nom) {
    if (typeof qgisProject === "undefined" || !qgisProject)
      return undefined;
    return ExpressionContextUtils.projectVariables(qgisProject)[nom];
  }

  function definirVariableProjet(nom, valeur) {
    if (typeof qgisProject === "undefined" || !qgisProject)
      return;
    ExpressionContextUtils.setProjectVariable(qgisProject, nom, valeur === undefined ? "" : valeur);
  }
}
