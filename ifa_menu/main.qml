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
//    SessionCloud.qml          jeton et appels authentifiés à QFieldCloud
//    ServiceUE.qml             recherche des UE sur le serveur
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
    },
    {
      "id": "validation",
      "titre": qsTr("Validation des données"),
      "soustitre": qsTr("Conformité de ce qui a été synchronisé"),
      "icone": "ic_check_white_24dp",
      "accent": "mainColor",
      "commandes": [
        {
          "id": "validation_rapport",
          "titre": qsTr("Rapport de validation"),
          "soustitre": qsTr("Anomalies relevées par le serveur"),
          "icone": "ic_check_white_24dp",
          "fichier": "FenetreValidation.qml"
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

  // Session QFieldCloud : URL du serveur, jeton et appels authentifiés. Une
  // seule instance également — deux sessions demanderaient deux fois le mot de
  // passe et se voleraient mutuellement leur jeton (voir SessionCloud.qml).
  SessionCloud {
    id: sessionCloud
  }

  // ===========================================================================
  //  Validation des données synchronisées
  // ===========================================================================
  //  Le service vit ici, et non dans une fenêtre : il guette le fichier de
  //  deltas de QField pour savoir quand une synchronisation part, ce qui doit
  //  se faire que le menu soit ouvert ou non.
  //
  //  C'est l'ancien plugin autonome « Rapport IFE » (`plugin_event.qml`), fondu
  //  dans celui-ci : un seul jeton, une seule demande de mot de passe.
  ServiceValidation {
    id: serviceValidation

    session: sessionCloud
    referentiels: donneesReferentiels

    // Une synchronisation vient d'être acceptée par le serveur. Avant toute
    // requête — et donc avant que la session ne réclame le mot de passe —, on
    // demande au technicien s'il rend son unité.
    onPousseDetecte: function (codeUnite) {
      dialogueDeverrouillage.demander(codeUnite);
    }

    // Le verdict, à l'écran, sans avoir à ouvrir la fenêtre. Seulement pour le
    // rapport qu'on guettait après une synchronisation : en annoncer un à
    // chaque ouverture de projet ou à chaque « Rafraîchir » serait du bruit.
    onRapportRecu: function (apresPousse) {
      if (!apresPousse)
        return;

      if (!serviceValidation.rapport) {
        plugin.avertir(qsTr("Rapport de validation reçu."));
        return;
      }

      if (serviceValidation.rapport.is_valid) {
        plugin.avertir(qsTr("Validation terminée : données conformes."), "success");
        return;
      }

      plugin.avertir(qsTr("Validation terminée : %n anomalie(s) bloquante(s). Ouvrez le rapport.", "", serviceValidation.nombreErreurs), "warning");
    }

    onEchec: function (message) {
      plugin.avertir(qsTr("Rapport de validation : %1").arg(message), "error");
    }
  }

  //  La question du déverrouillage, et l'appel qui va avec. Le rapport de
  //  validation n'est demandé qu'ensuite, quelle que soit la réponse : les
  //  deux sont indépendants, mais les faire partir ensemble ferait surgir la
  //  demande de mot de passe par-dessus le dialogue.
  DialogueDeverrouillage {
    id: dialogueDeverrouillage

    session: sessionCloud

    onTermine: function (deverrouille) {
      serviceValidation.attendreRapportFrais();

      // La fenêtre de validation n'est pas ouverte à ce moment-là : sans ce
      // message, rien ne dirait au technicien que le serveur travaille pour
      // lui. Le bouton de la barre d'outils bat, mais il faut le regarder.
      plugin.avertir(qsTr("Modifications synchronisées — validation en cours sur le serveur…"));
    }
  }

  // ===========================================================================
  //  Initialisation
  // ===========================================================================
  Component.onCompleted: {
    iface.logMessage("[IFA] plugin menu — chargement");
    iface.addItemToPluginsToolbar(boutonDemarrer);
    iface.addItemToPluginsToolbar(boutonValidation);
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
      if (boutonDemarrer.parent && boutonValidation.parent) {
        stop();
        return;
      }
      if (essais > 20) {
        stop();
        iface.logMessage("[IFA] barre d'outils indisponible : bouton non ajouté");
        return;
      }
      essais++;
      if (!boutonDemarrer.parent)
        iface.addItemToPluginsToolbar(boutonDemarrer);
      if (!boutonValidation.parent)
        iface.addItemToPluginsToolbar(boutonValidation);
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
  //  Bouton d'état de la validation
  // ===========================================================================
  //  Sa couleur est toute son utilité : vert, les données synchronisées sont
  //  conformes ; rouge, elles ne le sont pas ; gris, l'affichage n'engage rien
  //  — rapport absent, saisie non synchronisée, ou validation en cours. Un
  //  technicien voit l'état sans ouvrir quoi que ce soit.
  //
  //  Tant qu'on attend le serveur, le bouton **clignote** : une icône qui
  //  change sans bouger ne se remarque pas dans une barre d'outils, et l'attente
  //  est justement le moment où le technicien a besoin de savoir qu'il se passe
  //  quelque chose.
  //
  //  Le clignotement vient d'une minuterie qui bascule un booléen, et non d'une
  //  animation. `QfToolButton` appartient à QField : ce qu'il fait de son
  //  `opacity`, de son `scale` ou de son `rotation` ne nous appartient pas, et
  //  une animation qu'il neutraliserait échouerait en silence — c'est ce qui
  //  s'est produit. Une minuterie qui change une propriété liée, elle, ne peut
  //  que repeindre.
  property bool phaseAttente: false

  Timer {
    id: clignotantValidation

    interval: 550
    repeat: true
    running: serviceValidation.attenteVisible

    onTriggered: plugin.phaseAttente = !plugin.phaseAttente
    onRunningChanged: {
      if (!running)
        plugin.phaseAttente = false;
    }
  }

  QfToolButton {
    id: boutonValidation

    round: true
    bgcolor: {
      if (serviceValidation.attenteVisible)
        return plugin.phaseAttente ? Theme.mainColor : Theme.secondaryTextColor;
      if (serviceValidation.etat === "valide")
        return Theme.goodColor;
      if (serviceValidation.etat === "invalide")
        return Theme.errorColor;
      return Theme.secondaryTextColor;
    }
    iconSource: Theme.getThemeVectorIcon(serviceValidation.attenteVisible ? "ic_processing_black_24dp" : "ic_check_white_24dp")
    iconColor: "white"

    ToolTip.visible: hovered
    ToolTip.text: {
      if (serviceValidation.attenteVisible)
        return serviceValidation.diagnostic !== "" ? serviceValidation.diagnostic : qsTr("Validation en cours…");
      if (serviceValidation.deltasEnAttente)
        return qsTr("Modifications non synchronisées");
      if (serviceValidation.etat === "valide")
        return qsTr("Données valides");
      if (serviceValidation.etat === "invalide")
        return qsTr("%n anomalie(s) bloquante(s)", "", serviceValidation.nombreErreurs);
      return qsTr("Validation — aucun rapport à jour");
    }

    onClicked: plugin.ouvrirValidation()
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
      item.session = sessionCloud;
      item.validation = serviceValidation;
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

    // Le menu doit se refermer, et pas seulement passer au second plan : c'est
    // une fenêtre modale, son voile continuerait sinon d'intercepter les gestes
    // même une fois recouverte. Une fenêtre qui se referme pour libérer la
    // carte — le tracé d'emprise — retomberait alors sur le menu au lieu de la
    // carte.
    //
    // Le menu n'est pas rouvert à la fermeture de la commande : « Créer une UE »
    // enchaîne sur le formulaire de saisie de QField, que le menu masquerait.
    // Le bouton de la barre d'outils reste disponible pour y revenir.
    menuPrincipal.close();

    // Décharge explicitement la fenêtre précédente avant d'en charger une
    // autre : sans cela, réactiver la même commande ne relance pas onLoaded.
    chargeurFenetre.source = "";
    chargeurFenetre.source = commande.fichier;
  }

  // Le bouton d'état de la barre d'outils ouvre la même fenêtre que la
  // commande du menu : le registre reste la seule définition de celle-ci.
  function ouvrirValidation() {
    for (let i = 0; i < sections.length; ++i) {
      const commandes = sections[i].commandes;

      for (let j = 0; j < commandes.length; ++j) {
        if (commandes[j].id === "validation_rapport") {
          ouvrirCommande(commandes[j]);
          return;
        }
      }
    }
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
