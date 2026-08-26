// =============================================================================
//  IFA 2.0 — Plugin « Menu »  (point d'entrée du programme)
// =============================================================================
//  Ajoute un bouton « démarrer » dans la barre d'outils de QField. Un appui
//  ouvre le menu principal, d'où partent toutes les fonctions du programme.
//
//  Ce fichier ne contient que le câblage :
//    1. le bouton de la barre d'outils ;
//    2. le registre des menus et commandes (`sections`) ;
//    3. le routage vers la fenêtre correspondante (`ouvrirCommande`).
//
//  ---------------------------------------------------------------------------
//  AJOUTER UNE COMMANDE
//  ---------------------------------------------------------------------------
//    1. Créer un fichier Fenetre<Xxx>.qml à côté de celui-ci
//       (partir de FenetreCreerUE.qml pour un formulaire complet, ou de
//        FenetreCreerProjet.qml pour un squelette).
//    2. Ajouter une entrée dans `sections` ci-dessous, avec le nom du fichier.
//
//  Aucune autre modification n'est nécessaire : le menu se construit à partir
//  du registre, et les fenêtres sont chargées à la demande.
//
//  ---------------------------------------------------------------------------
//  FICHIERS DU PLUGIN
//  ---------------------------------------------------------------------------
//    main.qml                  ce fichier — bouton, registre, routage
//    MenuPrincipal.qml         la fenêtre du menu
//    IfaPopup.qml              coquille commune des fenêtres (responsive)
//    IfaCommande.qml           une ligne de commande du menu
//    IfaChantier.qml           bandeau « fonction à venir »
//    Referentiels.qml          listes de référence + accès aux couches
//    Fenetre*.qml              une fenêtre par commande
// =============================================================================

import QtQuick
import QtQuick.Controls

import org.qfield
import org.qgis
import Theme

Item {
  id: plugin

  // ===========================================================================
  //  Registre des menus
  // ===========================================================================
  //  accent  : nom d'une couleur du thème QField (Theme.mainColor,
  //            Theme.cloudColor, …) — permet de rester lisible en thème sombre.
  //  icone   : nom d'une icône du thème QField (sans le chemin ni l'extension).
  //  fichier : composant ouvert au clic. Laisser vide pour une commande encore
  //            non implémentée : elle est alors marquée « à venir » dans le
  //            menu et affiche un message.
  readonly property var sections: [
    {
      "id": "projets",
      "titre": qsTr("Gestionnaire de projet"),
      "soustitre": qsTr("Projets d'inventaire et de sondage"),
      "icone": "ic_project_folder_black_24dp",
      "accent": "mainColor",
      "commandes": [
        {
          "id": "projet_creer",
          "titre": qsTr("Créer un projet"),
          "soustitre": qsTr("Déclarer un projet et ses types d'UE"),
          "icone": "ic_add_white_24dp",
          "fichier": "FenetreCreerProjet.qml"
        },
        {
          "id": "projet_modifier",
          "titre": qsTr("Modifier / Afficher un projet"),
          "soustitre": qsTr("Consulter ou corriger un projet existant"),
          "icone": "ic_edit_attributes_white_24dp",
          "fichier": "FenetreModifierProjet.qml"
        }
      ]
    },
    {
      "id": "ue",
      "titre": qsTr("Gestionnaire d'unité d'échantillonnage"),
      "soustitre": qsTr("Unités d'échantillonnage (UE)"),
      "icone": "ic_geometry_point_24dp",
      "accent": "cloudColor",
      "commandes": [
        {
          "id": "ue_creer",
          "titre": qsTr("Créer une UE"),
          "soustitre": qsTr("Région, projet, type d'UE et plan d'eau"),
          "icone": "ic_add_white_24dp",
          "fichier": "FenetreCreerUE.qml"
        },
        {
          "id": "ue_consulter",
          "titre": qsTr("Consulter une UE"),
          "soustitre": qsTr("Rechercher et afficher une unité existante"),
          "icone": "ic_baseline_search_white",
          "fichier": "FenetreConsulterUE.qml"
        }
      ]
    }
  ]

  // ===========================================================================
  //  Données partagées
  // ===========================================================================
  // Instance unique, injectée dans chaque fenêtre au moment de son chargement.
  // L'identifiant diffère volontairement du nom de la propriété `referentiels`
  // des fenêtres : en QML, `referentiels: referentiels` se résoudrait sur la
  // propriété elle-même, pas sur cet objet.
  Referentiels {
    id: donneesReferentiels
  }

  // ===========================================================================
  //  Initialisation
  // ===========================================================================
  Component.onCompleted: {
    iface.logMessage("[IFA] plugin menu — chargement");
    iface.addItemToPluginsToolbar(boutonDemarrer);
    minuterieBarreOutils.start();
  }

  // La barre d'outils des plugins n'est pas toujours construite au moment où le
  // plugin est chargé — c'est notamment le cas d'un plugin d'application, chargé
  // très tôt. On réessaie jusqu'à ce que le bouton soit effectivement rattaché.
  Timer {
    id: minuterieBarreOutils

    interval: 500
    repeat: true

    property int essais: 0

    onTriggered: {
      if (boutonDemarrer.parent) {
        stop();
        return;
      }
      if (essais > 20) {
        stop();
        iface.logMessage("[IFA] barre d'outils indisponible : bouton non ajouté");
        return;
      }
      essais++;
      iface.addItemToPluginsToolbar(boutonDemarrer);
    }
  }

  // ===========================================================================
  //  Bouton de la barre d'outils
  // ===========================================================================
  QfToolButton {
    id: boutonDemarrer

    round: true
    bgcolor: Theme.mainColor
    iconSource: Theme.getThemeVectorIcon("ic_play_black_24dp")
    iconColor: Theme.darkGray

    ToolTip.visible: hovered
    ToolTip.text: qsTr("IFA 2.0 — Démarrer")

    onClicked: menuPrincipal.open()
  }

  // ===========================================================================
  //  Menu principal
  // ===========================================================================
  MenuPrincipal {
    id: menuPrincipal

    sections: plugin.sections
    referentiels: donneesReferentiels

    onCommandeChoisie: function (commande) {
      plugin.ouvrirCommande(commande);
    }
  }

  // ===========================================================================
  //  Fenêtres des commandes
  // ===========================================================================
  //  Chargement à la demande : une seule fenêtre vit à la fois. Cela évite
  //  d'instancier tous les formulaires au démarrage, et isole les pannes — une
  //  fenêtre en erreur ne rend pas le menu inutilisable.
  //
  //  La fenêtre n'est PAS détruite à sa fermeture, mais au chargement de la
  //  suivante. Une fenêtre peut ainsi se refermer puis se rouvrir en conservant
  //  sa saisie — ce dont a besoin le tracé d'emprise sur la carte, qui exige de
  //  libérer l'écran le temps du tracé.
  Loader {
    id: chargeurFenetre

    onLoaded: {
      if (!item)
        return;

      item.referentiels = donneesReferentiels;
      item.open();
    }

    onStatusChanged: {
      if (status === Loader.Error) {
        iface.logMessage("[IFA] échec du chargement de " + source);
        plugin.avertir(qsTr("Cette fonction n'a pas pu être ouverte. Voir le journal des messages."), "error");
        source = "";
      }
    }
  }

  // ===========================================================================
  //  Fonctions
  // ===========================================================================
  function ouvrirCommande(commande) {
    if (!commande || !commande.fichier) {
      avertir(qsTr("« %1 » n'est pas encore disponible.").arg(commande ? commande.titre : ""), "info");
      return;
    }

    // Décharge explicitement la fenêtre précédente avant d'en charger une
    // autre : sans cela, réactiver la même commande ne relance pas onLoaded.
    chargeurFenetre.source = "";
    chargeurFenetre.source = commande.fichier;
  }

  function avertir(message, type) {
    const principale = iface.mainWindow();
    if (principale && typeof principale.displayToast === "function") {
      principale.displayToast(message, type ? type : "info");
    } else {
      iface.logMessage("[IFA] " + message);
    }
  }
}
