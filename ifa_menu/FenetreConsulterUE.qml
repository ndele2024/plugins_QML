// =============================================================================
//  FenetreConsulterUE — recherche et consultation des unités d'échantillonnage
// =============================================================================
//  Deux étapes dans une même fenêtre :
//
//    0. Filtre    — région, n° de plan d'eau, nom de bassin, zone
//                   personnalisée, code d'UE — seuls ou croisés.
//    1. Résultats — tableau des unités renvoyées, avec trois actions par ligne.
//
//  Les critères se cochent indépendamment et se croisent : une unité doit les
//  satisfaire tous. Chaque critère coché resserre donc la liste. C'est ce qui
//  rend la recherche par région praticable — seule, elle rend plus de douze
//  mille unités ; croisée avec un bassin, elle en rend quelques dizaines.
//
//  Les résultats viennent du point d'accès `POST /api/v1/ifa/unites/recherche/`
//  de QFieldCloud, par l'intermédiaire de `ServiceUE` (interrogation) et de
//  `SessionCloud` (jeton). Voir l'en-tête de ces deux fichiers.
//
//  La réponse est paginée : une recherche par région dépasse couramment les
//  10 000 unités. La fenêtre affiche le décompte complet et propose de charger
//  la suite ; `ServiceUE` rend la liste déjà cumulée.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import org.qgis
import Theme

IfaPopup {
  id: fenetre

  titre: qsTr("Consulter une UE")
  soustitre: etape === 0 ? qsTr("Choisir un ou plusieurs critères") : qsTr("%n unité(s) trouvée(s)", "", service.total)
  icone: "ic_baseline_search_white"
  accent: Theme.cloudColor

  // Un tableau a besoin de plus de place qu'un formulaire.
  largeurMax: 920

  // Bandeau d'attente épinglé sous l'en-tête (voir `IfaPopup`). Le verrouillage
  // puis le packaging prennent de quelques secondes à quelques minutes, et la
  // liste des résultats défile : un bandeau posé dans le flux sortirait de
  // l'écran au moment même où le technicien clique.
  //
  // Le bandeau court jusqu'à l'ouverture du projet : une fois le packaging
  // fini, le passeur prend le relais (téléchargement, ouverture) avec ses
  // propres messages.
  activite: ouverture.enCours ? messageOuverture : (passeurActif ? passeur.message : "")

  readonly property bool passeurActif: passeur !== null && passeur.enCours

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  // 0 = choix du filtre, 1 = résultats
  property int etape: 0

  // Les critères proposés, dans l'ordre où ils s'affichent. `ChoixCriteres`
  // reprend cet ordre pour la sélection : le résumé du filtre se lit donc
  // toujours de la même façon, quel que soit l'ordre des clics.
  readonly property var criteresDisponibles: [
    {
      cle: "region",
      libelle: qsTr("Région")
    },
    {
      cle: "lce",
      libelle: qsTr("N° de plan d'eau")
    },
    {
      cle: "bassin",
      libelle: qsTr("Nom du bassin")
    },
    {
      cle: "emprise",
      libelle: qsTr("Zone personnalisée")
    },
    {
      cle: "code",
      libelle: qsTr("Code d'UE")
    }
  ]

  // Les critères cochés. La région seule est le point de départ courant.
  property var criteresActifs: ["region"]

  property var unites: []
  property string messageErreur: ""
  property bool rechercheLancee: false

  // Avancement de l'ouverture d'une unité (verrouillage, packaging).
  property string messageOuverture: ""

  // Emprise personnalisée (voir SelecteurEmprise).
  property string empriseWkt: ""
  property var empriseBbox: null
  property int empriseNombreSommets: 0
  property var empriseSommets: []

  // Tous les critères cochés doivent être renseignés : croiser un critère
  // resserre la recherche, et un critère coché mais vide ne resserrerait rien
  // — le technicien croirait avoir filtré sur quelque chose.
  readonly property bool filtrePret: {
    if (criteresActifs.length === 0)
      return false;

    for (let i = 0; i < criteresActifs.length; ++i) {
      if (!critereRenseigne(criteresActifs[i]))
        return false;
    }

    return true;
  }

  // ===========================================================================
  //  ÉTAPE 0 — filtre
  // ===========================================================================
  GridLayout {
    id: grille

    Layout.fillWidth: true
    visible: fenetre.etape === 0

    columns: fenetre.compact ? 1 : 2
    columnSpacing: 16
    rowSpacing: fenetre.compact ? 4 : 10

    Label {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.bottomMargin: 4
      text: qsTr("Sur quels critères rechercher les unités d'échantillonnage ?")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    // ---- Choix des critères ----------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: fenetre.compact ? 0 : 8
      text: qsTr("Filtrer sur")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ChoixCriteres {
      id: choixFiltre

      Layout.fillWidth: true
      // Un `Flow` calcule sa hauteur d'après sa largeur : sans l'annoncer au
      // GridLayout, les pastilles repliées sur un second rang seraient
      // coupées.
      Layout.preferredHeight: choixFiltre.implicitHeight
      Layout.minimumHeight: choixFiltre.implicitHeight

      accent: fenetre.accent
      criteres: fenetre.criteresDisponibles
      selection: fenetre.criteresActifs

      onSelectionChangee: function (selection) {
        fenetre.criteresActifs = selection;
      }
    }

    // ---- Ce que le croisement fait ---------------------------------------------
    //  Dit une fois, sous les pastilles, plutôt qu'à côté de chaque champ :
    //  c'est la règle de lecture de tout le bloc.
    Label {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.bottomMargin: 4

      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap

      text: {
        if (fenetre.criteresActifs.length === 0)
          return qsTr("Cochez au moins un critère.");
        if (fenetre.criteresActifs.length === 1)
          return qsTr("Cochez-en d'autres pour resserrer la recherche.");
        return qsTr("Les %n critères se croisent : seules les unités qui les satisfont tous seront affichées.", "", fenetre.criteresActifs.length);
      }
    }

    // ---- Région ----------------------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      visible: fenetre.estActif("region")
      text: qsTr("Région administrative")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ComboBox {
      id: comboRegion

      Layout.fillWidth: true
      visible: fenetre.estActif("region")

      textRole: "nom"
      valueRole: "code"
      currentIndex: -1
      model: fenetre.referentiels ? fenetre.referentiels.regions : []
    }

    // ---- N° de plan d'eau --------------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      visible: fenetre.estActif("lce")
      text: qsTr("N° du plan d'eau (LCE)")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    TextField {
      id: champLce

      Layout.fillWidth: true
      visible: fenetre.estActif("lce")

      maximumLength: 8
      placeholderText: qsTr("ex. 12777")
      inputMethodHints: Qt.ImhDigitsOnly
      validator: IntValidator {}
      onAccepted: fenetre.lancerRecherche()
    }

    // ---- Nom du bassin -------------------------------------------------------------
    //  Le nom du bassin versant est porté par `infor_gener.ing_nom_bassi`, un
    //  texte libre du fonds hérité : on y trouve « Saguenay » comme
    //  « SAGUENAY (BASSIN) ». La recherche est donc partielle et insensible à
    //  la casse, comme celle par code — exiger la graphie exacte réserverait le
    //  critère à ceux qui connaissent déjà ce que la base contient.
    Label {
      Layout.fillWidth: fenetre.compact
      visible: fenetre.estActif("bassin")
      text: qsTr("Nom du bassin")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: fenetre.estActif("bassin")
      spacing: 2

      TextField {
        id: champBassin

        Layout.fillWidth: true
        placeholderText: qsTr("ex. Saguenay, Outaouais…")
        onAccepted: fenetre.lancerRecherche()
      }

      Label {
        Layout.fillWidth: true
        text: qsTr("Recherche partielle : tout fragment du nom convient, majuscules ou non. Deux caractères minimum.")
        font: Theme.tinyFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }
    }

    // ---- Code d'UE ---------------------------------------------------------------
    //  La recherche est partielle : n'importe quel fragment du code convient.
    //  D'où l'absence de `Qt.ImhUppercaseOnly` — quelques familles historiques
    //  (réseau ANRO) portent des minuscules, et forcer les capitales à l'écran
    //  laisserait croire qu'elles comptent. Le serveur ignore la casse.
    Label {
      Layout.fillWidth: fenetre.compact
      visible: fenetre.estActif("code")
      text: qsTr("Code de l'unité")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: fenetre.estActif("code")
      spacing: 2

      TextField {
        id: champCode

        Layout.fillWidth: true
        font: Theme.strongFont
        placeholderText: qsTr("ex. 12777, ANRO, 02-127…")
        onAccepted: fenetre.lancerRecherche()
      }

      Label {
        Layout.fillWidth: true
        text: qsTr("Recherche partielle : tout fragment du code convient, majuscules ou non. Deux caractères minimum.")
        font: Theme.tinyFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }
    }

    // ---- Zone personnalisée --------------------------------------------------------
    Rectangle {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.preferredHeight: blocEmprise.implicitHeight + 24

      visible: fenetre.estActif("emprise")

      radius: 12
      color: Theme.controlBackgroundAlternateColor
      border.width: 1
      border.color: fenetre.empriseWkt !== "" ? Qt.rgba(fenetre.accent.r, fenetre.accent.g, fenetre.accent.b, 0.5) : Theme.controlBorderColor

      ColumnLayout {
        id: blocEmprise

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          IconImage {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            source: Theme.getThemeVectorIcon(fenetre.empriseWkt !== "" ? "ic_check_white_24dp" : "ic_geometry_polygon_24dp")
            color: fenetre.empriseWkt !== "" ? Theme.goodColor : Theme.secondaryTextColor
            sourceSize: Qt.size(44, 44)
          }

          Label {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            font: Theme.tipFont
            color: Theme.mainTextColor
            wrapMode: Text.WordWrap
            text: fenetre.empriseWkt !== "" ? qsTr("Zone définie — %n sommet(s)", "", fenetre.empriseNombreSommets) : qsTr("Aucune zone définie")
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          QfButton {
            Layout.fillWidth: true
            text: fenetre.empriseWkt !== "" ? qsTr("Modifier sur la carte") : qsTr("Tracer sur la carte")
            bgcolor: fenetre.accent
            color: fenetre.surAccent
            onClicked: fenetre.tracerEmprise()
          }

          QfButton {
            visible: fenetre.empriseWkt !== ""
            text: qsTr("Effacer")
            bgcolor: "transparent"
            color: Theme.secondaryTextColor
            borderColor: Theme.controlBorderColor
            onClicked: fenetre.effacerEmprise()
          }
        }
      }
    }
  }

  // ===========================================================================
  //  ÉTAPE 1 — résultats
  // ===========================================================================
  ColumnLayout {
    Layout.fillWidth: true
    visible: fenetre.etape === 1
    spacing: 12

    // ---- Rappel du filtre ------------------------------------------------------
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: ligneRappel.implicitHeight + 20

      radius: 10
      color: Qt.rgba(fenetre.accent.r, fenetre.accent.g, fenetre.accent.b, 0.10)

      RowLayout {
        id: ligneRappel

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8

        IconImage {
          Layout.preferredWidth: 18
          Layout.preferredHeight: 18
          Layout.alignment: Qt.AlignVCenter
          source: Theme.getThemeVectorIcon("ic_baseline_search_white")
          color: fenetre.accent
          sourceSize: Qt.size(36, 36)
        }

        Label {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: fenetre.resumeFiltre()
          font: Theme.tipFont
          color: Theme.mainTextColor
          wrapMode: Text.WordWrap
        }

        QfButton {
          text: qsTr("Modifier")
          bgcolor: "transparent"
          color: fenetre.accent
          onClicked: fenetre.etape = 0
        }
      }
    }

    // ---- Interrogation en cours --------------------------------------------------
    //  Masqué pendant le chargement d'une page suivante : le tableau reste à
    //  l'écran, l'attente est signalée par le bouton en bas.
    ColumnLayout {
      Layout.fillWidth: true
      Layout.topMargin: 30
      Layout.bottomMargin: 30
      visible: service.enCours && fenetre.unites.length === 0
      spacing: 14

      BusyIndicator {
        Layout.alignment: Qt.AlignHCenter
        running: service.enCours
      }

      Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("Interrogation du serveur…")
        font: Theme.tipFont
        color: Theme.secondaryTextColor
      }
    }

    // ---- Échec ---------------------------------------------------------------------
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: texteErreur.implicitHeight + 24

      visible: !service.enCours && fenetre.messageErreur !== ""

      radius: 10
      color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.14)
      border.width: 1
      border.color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.4)

      Label {
        id: texteErreur

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        text: fenetre.messageErreur
        font: Theme.tipFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }
    }

    // ---- Aucun résultat --------------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      Layout.topMargin: 26
      Layout.bottomMargin: 26

      visible: !service.enCours && fenetre.messageErreur === "" && fenetre.rechercheLancee && fenetre.unites.length === 0
      spacing: 12

      IconImage {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        source: Theme.getThemeVectorIcon("ic_dissatisfied_white_24dp")
        color: Theme.secondaryTextColor
        sourceSize: Qt.size(80, 80)
      }

      Label {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: qsTr("Aucune unité ne correspond à ce filtre.")
        font: Theme.tipFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }
    }

    // ---- Tableau -----------------------------------------------------------------------
    TableauUE {
      Layout.fillWidth: true

      // Le tableau reste affiché pendant le chargement d'une page suivante :
      // le faire disparaître ferait sauter l'écran sous les doigts.
      visible: fenetre.unites.length > 0

      lignes: fenetre.unites
      accent: fenetre.accent

      // C'est lui qui décide si le cadenas d'une unité tenue s'ouvre ou reste
      // fermé : seul son détenteur peut lever un verrou.
      utilisateur: fenetre.session ? fenetre.session.utilisateur : ""

      uniteEnCours: ouverture.enCours || fenetre.passeurActif ? ouverture.uniteCourante : ""
      uniteDeverrouillage: verrouillage.enCours ? verrouillage.uniteCourante : ""

      onOuvrirVerrouille: function (unite) {
        fenetre.ouvrirUnite(unite, true);
      }
      onOuvrirLecture: function (unite) {
        fenetre.ouvrirUnite(unite, false);
      }
      onDeverrouiller: function (unite) {
        fenetre.demanderDeverrouillage(unite);
      }
      onSupprimer: function (unite) {
        fenetre.demanderSuppression(unite);
      }
    }

    // ---- Suite des résultats ------------------------------------------------------
    //  Le serveur ne rend qu'une page à la fois. Afficher le reste est un
    //  geste volontaire : sur une liaison de terrain, charger 12 000 unités
    //  sans le demander serait au mieux long, au pire coûteux.
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 4

      visible: fenetre.unites.length > 0 && (service.tronque || service.enCours)
      spacing: 10

      Label {
        Layout.fillWidth: true
        text: qsTr("%1 sur %2 affichées").arg(fenetre.unites.length).arg(service.total)
        font: Theme.tipFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }

      BusyIndicator {
        Layout.preferredWidth: 22
        Layout.preferredHeight: 22
        running: service.enCours
        visible: service.enCours
      }

      QfButton {
        visible: service.tronque
        text: qsTr("Afficher les suivantes")
        enabled: !service.enCours
        bgcolor: "transparent"
        color: fenetre.accent
        borderColor: Theme.controlBorderColor
        onClicked: service.pageSuivante()
      }
    }
  }

  // ===========================================================================
  //  Actions du pied de page
  // ===========================================================================
  actions: [
    QfButton {
      visible: fenetre.etape === 1
      text: qsTr("Nouvelle recherche")
      bgcolor: "transparent"
      color: Theme.mainTextColor
      borderColor: Theme.controlBorderColor
      onClicked: fenetre.etape = 0
    },
    QfButton {
      text: qsTr("Fermer")
      bgcolor: "transparent"
      color: Theme.secondaryTextColor
      onClicked: fenetre.close()
    },
    QfButton {
      visible: fenetre.etape === 0
      text: qsTr("Rechercher")
      enabled: fenetre.filtrePret
      bgcolor: fenetre.accent
      color: fenetre.surAccent
      onClicked: fenetre.lancerRecherche()
    }
  ]

  // ===========================================================================
  //  Service de données
  // ===========================================================================
  ServiceUE {
    id: service

    session: fenetre.session

    onResultats: function (lignes) {
      fenetre.unites = lignes;
      fenetre.messageErreur = "";
    }

    onEchec: function (message) {
      // Les unités déjà reçues restent affichées : si c'est le chargement
      // d'une page suivante qui a échoué, vider la liste ferait perdre au
      // technicien ce qu'il avait sous les yeux.
      fenetre.messageErreur = message;
    }
  }

  // Ouverture d'une unité dans QField : verrouillage, préparation du projet
  // d'affichage, attente du packaging. Voir `ServiceOuverture.qml`.
  ServiceOuverture {
    id: ouverture

    session: fenetre.session
    passeur: fenetre.passeur

    // Le bandeau pour la fenêtre, la fenêtre d'attente centrée pour tout le
    // parcours : le passeur la reprend après le packaging et la referme à
    // l'ouverture du projet.
    onProgression: function (message) {
      fenetre.messageOuverture = message;
      if (fenetre.attente)
        fenetre.attente.suivre(ouverture.modeCourant === "modifiable" ? qsTr("Ouverture de l'unité %1 (modifiable)").arg(ouverture.uniteCourante) : qsTr("Ouverture de l'unité %1 (consultation)").arg(ouverture.uniteCourante), message);
    }

    // Plus de toast ici : la fenêtre d'attente enchaîne sur le téléchargement.
    onPret: function (infos) {
      fenetre.messageOuverture = "";
      fenetre.appliquerVerrou(infos["verrou"]);
    }

    onEchec: function (message) {
      fenetre.messageOuverture = "";
      if (fenetre.attente)
        fenetre.attente.terminer();
      fenetre.messageErreur = message;
      avertir(message, "warning");
    }
  }

  // Levée du verrou, à la demande de son détenteur. Voir `ServiceVerrou.qml`.
  ServiceVerrou {
    id: verrouillage

    session: fenetre.session

    onDeverrouille: function (verrou, change) {
      fenetre.appliquerVerrou(verrou);

      // `change` est faux quand l'unité n'était déjà plus verrouillée — un
      // collègue l'a rendue entre-temps, ou une préparation qui avait échoué
      // a relâché son verrou. Ce n'est pas une erreur : le résultat voulu est
      // là. Mais le dire évite au technicien de croire que son geste a porté.
      if (change)
        avertir(qsTr("Unité %1 déverrouillée — elle est de nouveau disponible.").arg(verrou["une_code_ident"]), "success");
      else
        avertir(qsTr("L'unité %1 n'était déjà plus verrouillée.").arg(verrou["une_code_ident"]), "info");
    }

    onEchec: function (message) {
      fenetre.messageErreur = message;
      avertir(message, "warning");
    }
  }

  // Le motif du verrouillage est demandé avant l'envoi : c'est lui que liront
  // les autres équipes si elles tentent d'ouvrir la même unité.
  DialogueRaisonVerrou {
    id: dialogueRaison

    zoneParente: fenetre.zoneUtile

    onValide: function (raison) {
      ouverture.ouvrir(dialogueRaison.unite, "modifiable", raison);
    }
  }

  // ===========================================================================
  //  Tracé de la zone personnalisée
  // ===========================================================================
  SelecteurEmprise {
    id: selecteurEmprise

    accent: fenetre.accent

    onValide: function (wkt, bbox, nombreSommets) {
      fenetre.empriseWkt = wkt;
      fenetre.empriseBbox = bbox;
      fenetre.empriseNombreSommets = nombreSommets;
      fenetre.empriseSommets = selecteurEmprise.sommets;
      fenetre.open();
    }

    onAnnule: fenetre.open()

    Component.onDestruction: selecteurEmprise.reinitialiserAffichage()
  }

  // ===========================================================================
  //  Confirmation du déverrouillage
  // ===========================================================================
  //  Rendre une unité n'est pas rattrapable d'un clic : une autre équipe peut
  //  la prendre dans la minute, et il faudra alors attendre qu'elle la rende.
  //  D'où une confirmation, qui nomme l'unité — le tableau est dense et les
  //  lignes se ressemblent.
  Popup {
    id: confirmationDeverrouillage

    property var unite: null

    parent: fenetre.zoneUtile
    width: Math.min(parent ? parent.width - 40 : 320, 400)
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0

    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    background: Rectangle {
      color: Theme.mainBackgroundColor
      radius: 14
      border.width: 1
      border.color: Theme.controlBorderColor
    }

    contentItem: ColumnLayout {
      spacing: 14

      Label {
        Layout.fillWidth: true
        Layout.topMargin: 18
        Layout.leftMargin: 18
        Layout.rightMargin: 18
        text: qsTr("Déverrouiller cette unité ?")
        font: Theme.strongFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }

      Label {
        Layout.fillWidth: true
        Layout.leftMargin: 18
        Layout.rightMargin: 18
        text: confirmationDeverrouillage.unite ? qsTr("L'unité %1 redeviendra disponible pour les autres équipes. Synchronisez vos modifications avant de la rendre : une fois reprise par quelqu'un d'autre, vous ne pourrez plus la verrouiller.").arg(confirmationDeverrouillage.unite["une_code_ident"]) : ""
        font: Theme.tipFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 14
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        spacing: 8

        Item {
          Layout.fillWidth: true
        }

        QfButton {
          text: qsTr("Annuler")
          bgcolor: "transparent"
          color: Theme.secondaryTextColor
          onClicked: confirmationDeverrouillage.close()
        }

        QfButton {
          text: qsTr("Déverrouiller")
          bgcolor: Theme.warningColor
          color: "#ffffff"
          onClicked: {
            fenetre.deverrouillerUnite(confirmationDeverrouillage.unite);
            confirmationDeverrouillage.close();
          }
        }
      }
    }
  }

  // ===========================================================================
  //  Confirmation de suppression
  // ===========================================================================
  //  Une suppression n'est pas rattrapable : elle passe forcément par une
  //  confirmation nommant l'unité concernée.
  Popup {
    id: confirmationSuppression

    property var unite: null

    parent: fenetre.zoneUtile
    width: Math.min(parent ? parent.width - 40 : 320, 400)
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0

    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    background: Rectangle {
      color: Theme.mainBackgroundColor
      radius: 14
      border.width: 1
      border.color: Theme.controlBorderColor
    }

    contentItem: ColumnLayout {
      spacing: 14

      Label {
        Layout.fillWidth: true
        Layout.topMargin: 18
        Layout.leftMargin: 18
        Layout.rightMargin: 18
        text: qsTr("Supprimer cette unité ?")
        font: Theme.strongFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }

      Label {
        Layout.fillWidth: true
        Layout.leftMargin: 18
        Layout.rightMargin: 18
        text: confirmationSuppression.unite ? qsTr("L'unité %1 et toutes ses données de terrain seront supprimées. Cette action est irréversible.").arg(confirmationSuppression.unite["une_code_ident"]) : ""
        font: Theme.tipFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 14
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        spacing: 8

        Item {
          Layout.fillWidth: true
        }

        QfButton {
          text: qsTr("Annuler")
          bgcolor: "transparent"
          color: Theme.secondaryTextColor
          onClicked: confirmationSuppression.close()
        }

        QfButton {
          text: qsTr("Supprimer")
          bgcolor: Theme.errorColor
          color: "#ffffff"
          onClicked: {
            fenetre.supprimerUnite(confirmationSuppression.unite);
            confirmationSuppression.close();
          }
        }
      }
    }
  }

  // ===========================================================================
  //  Fonctions
  // ===========================================================================

  function lancerRecherche() {
    if (!filtrePret)
      return;

    unites = [];
    messageErreur = "";
    rechercheLancee = true;
    etape = 1;

    service.rechercher(filtreCourant());
  }

  function estActif(mode) {
    return criteresActifs.indexOf(mode) !== -1;
  }

  // Un critère coché est-il utilisable ? Les bornes reprennent celles du
  // serveur : mieux vaut un bouton « Rechercher » éteint qu'un aller-retour
  // qui revient en erreur pour une saisie manifestement trop courte.
  function critereRenseigne(mode) {
    if (mode === "region")
      return comboRegion.currentIndex >= 0;
    if (mode === "lce")
      return champLce.text !== "";
    if (mode === "bassin")
      return champBassin.text.trim().length >= 2;
    if (mode === "code")
      return champCode.text.trim().length >= 2;
    return empriseWkt !== "";
  }

  // Les critères cochés, dans la forme attendue par `ServiceUE`.
  function filtreCourant() {
    const liste = [];

    for (let i = 0; i < criteresActifs.length; ++i) {
      liste.push(critereCourant(criteresActifs[i]));
    }

    return liste;
  }

  function critereCourant(mode) {
    if (mode === "region")
      return {
        "mode": "region",
        "valeur": comboRegion.currentValue
      };

    if (mode === "lce")
      return {
        "mode": "lce",
        "valeur": champLce.text
      };

    if (mode === "bassin")
      return {
        "mode": "bassin",
        "valeur": champBassin.text.trim()
      };

    if (mode === "code")
      return {
        "mode": "code",
        "valeur": champCode.text.trim()
      };

    return {
      "mode": "emprise",
      "wkt": empriseWkt,
      "bbox": empriseBbox
    };
  }

  // Le rappel affiché au-dessus des résultats. Les critères sont joints par
  // « et » : c'est bien une conjonction, et la phrase doit dire au technicien
  // pourquoi sa liste est courte.
  function resumeFiltre() {
    const morceaux = [];

    for (let i = 0; i < criteresActifs.length; ++i) {
      morceaux.push(resumeCritere(criteresActifs[i]));
    }

    if (morceaux.length === 0)
      return qsTr("Aucun critère");

    return morceaux.join(qsTr(" et "));
  }

  function resumeCritere(mode) {
    if (mode === "region")
      return qsTr("Région : %1").arg(comboRegion.currentIndex >= 0 ? comboRegion.currentText : "—");
    if (mode === "lce")
      return qsTr("Plan d'eau n° %1").arg(champLce.text);
    if (mode === "bassin")
      return qsTr("Bassin contenant « %1 »").arg(champBassin.text.trim());
    if (mode === "code")
      return qsTr("Code contenant « %1 »").arg(champCode.text.trim());
    return qsTr("Zone personnalisée — %n sommet(s)", "", empriseNombreSommets);
  }

  // ---- Emprise -----------------------------------------------------------------
  function tracerEmprise() {
    close();

    if (!selecteurEmprise.demarrer(empriseSommets)) {
      open();
      avertir(qsTr("La carte n'est pas accessible : tracé impossible."), "warning");
    }
  }

  function effacerEmprise() {
    empriseWkt = "";
    empriseBbox = null;
    empriseNombreSommets = 0;
    empriseSommets = [];
  }

  // ---- Actions sur une unité -------------------------------------------------------
  // Les deux ouvertures passent par `POST /api/v1/ifa/unites/<code>/ouvrir/`
  // (voir `ServiceOuverture.qml`). La suppression, elle, n'a toujours pas de
  // point d'accès : `DELETE /api/v1/ifa/unites/<code>/` reste à écrire.
  //
  // Le verrou renvoyé par la recherche (`une_ind_verro`, `une_nom_propr_verro`)
  // est déjà celui de la base : le tableau désactive correctement les actions
  // sur une unité tenue par quelqu'un d'autre.
  function ouvrirUnite(unite, avecVerrou) {
    if (!unite)
      return;

    if (ouverture.enCours || passeurActif) {
      avertir(qsTr("Ouverture de l'unité %1 en cours — patientez.").arg(ouverture.uniteCourante), "info");
      return;
    }

    messageErreur = "";

    // Avant tout appel au serveur : verrouiller une unité dont le projet ne
    // pourra pas remplacer le projet courant (modifications non
    // synchronisées, QField déconnecté) laisserait le technicien à mi-chemin.
    const empechement = passeur ? passeur.verifier() : "";
    if (empechement !== "") {
      messageErreur = empechement;
      avertir(empechement, "warning");
      return;
    }

    referentiels.definirVariableProjet("une_code_ident", unite["une_code_ident"]);

    if (avecVerrou) {
      // Le verrouillage attend la raison ; c'est le dialogue qui enchaîne.
      dialogueRaison.demander(unite);
      return;
    }

    // `ouverture.ouvrir()` remplit le bandeau dès son premier appel, mais la
    // fenêtre peut être défilée loin de lui : le toast donne le retour au
    // doigt, tout de suite. Le mode verrouillé, lui, a déjà son dialogue.
    avertir(qsTr("Préparation de l'unité %1…").arg(unite["une_code_ident"]), "info");

    ouverture.ouvrir(unite, "consultation", "");
  }

  // Remplace l'état de verrou d'une unité par celui que le serveur vient de
  // renvoyer, sans relancer la recherche : la ligne du tableau et son étiquette
  // de verrou se mettent à jour seules.
  function appliquerVerrou(verrou) {
    if (!verrou || !verrou["une_code_ident"])
      return;

    const misesAJour = [];

    for (let i = 0; i < unites.length; ++i) {
      const ligne = unites[i];

      if (ligne["une_code_ident"] !== verrou["une_code_ident"]) {
        misesAJour.push(ligne);
        continue;
      }

      const copie = {};
      for (const cle in ligne) {
        copie[cle] = ligne[cle];
      }
      for (const champ in verrou) {
        copie[champ] = verrou[champ];
      }
      misesAJour.push(copie);
    }

    unites = misesAJour;
  }

  // ---- Déverrouillage ---------------------------------------------------------------
  //  Le bouton n'apparaît que sur les unités que l'utilisateur tient lui-même
  //  (`TableauUE.estMoi()`), mais la liste peut avoir vieilli : un collègue a
  //  pu reprendre l'unité depuis la recherche. C'est le serveur qui tranche, et
  //  son refus nomme le nouveau détenteur.
  function demanderDeverrouillage(unite) {
    if (!unite)
      return;

    if (ouverture.enCours || passeurActif || verrouillage.enCours) {
      avertir(qsTr("Un traitement est déjà en cours — patientez."), "info");
      return;
    }

    confirmationDeverrouillage.unite = unite;
    confirmationDeverrouillage.open();
  }

  function deverrouillerUnite(unite) {
    if (!unite)
      return;

    messageErreur = "";
    verrouillage.deverrouiller(unite);
  }

  function demanderSuppression(unite) {
    confirmationSuppression.unite = unite;
    confirmationSuppression.open();
  }

  function supprimerUnite(unite) {
    if (!unite)
      return;

    // Retrait local, le temps que le service de suppression existe. L'unité
    // reste dans la base : elle réapparaîtra au prochain « Afficher les
    // suivantes », qui renvoie la liste telle que le serveur la connaît.
    const restantes = [];
    for (let i = 0; i < unites.length; ++i) {
      if (unites[i]["une_code_ident"] !== unite["une_code_ident"])
        restantes.push(unites[i]);
    }
    unites = restantes;

    avertir(qsTr("%1 retirée de la liste — suppression serveur non déployée.").arg(unite["une_code_ident"]), "warning");
    iface.logMessage("[IFA] supprimer " + unite["une_code_ident"]);
  }
}
