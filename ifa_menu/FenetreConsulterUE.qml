// =============================================================================
//  FenetreConsulterUE — recherche et consultation des unités d'échantillonnage
// =============================================================================
//  Deux étapes dans une même fenêtre :
//
//    0. Filtre    — région, n° de plan d'eau, zone personnalisée, ou code d'UE.
//    1. Résultats — tableau des unités renvoyées, avec trois actions par ligne.
//
//  ⚠️ Le point d'accès serveur n'existe pas encore : les résultats proviennent
//  de ServiceUE, qui les fabrique localement. Voir l'en-tête de ServiceUE.qml
//  pour le contrat à respecter le jour où le backend arrive — c'est le seul
//  fichier à reprendre, cette fenêtre n'a pas à changer.
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
  soustitre: etape === 0 ? qsTr("Choisir un filtre de recherche") : qsTr("%n unité(s) trouvée(s)", "", unites.length)
  icone: "ic_baseline_search_white"
  accent: Theme.cloudColor

  // Un tableau a besoin de plus de place qu'un formulaire.
  largeurMax: 920

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  // 0 = choix du filtre, 1 = résultats
  property int etape: 0

  readonly property var modesFiltre: ["region", "lce", "emprise", "code"]
  property string modeFiltre: "region"

  property var unites: []
  property string messageErreur: ""
  property bool rechercheLancee: false

  // Emprise personnalisée (voir SelecteurEmprise).
  property string empriseWkt: ""
  property var empriseBbox: null
  property int empriseNombreSommets: 0
  property var empriseSommets: []

  readonly property bool filtrePret: {
    if (modeFiltre === "region")
      return comboRegion.currentIndex >= 0;
    if (modeFiltre === "lce")
      return champLce.text !== "";
    if (modeFiltre === "code")
      return champCode.text.trim() !== "";
    return empriseWkt !== "";
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
      text: qsTr("Sur quel critère rechercher les unités d'échantillonnage ?")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    // ---- Choix du critère ------------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      text: qsTr("Filtrer sur")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    QfToggleButtonGroup {
      id: choixFiltre

      Layout.fillWidth: true
      // Le composant fixe sa `height` d'après son Flow interne ; sans cette
      // hauteur minimale, le GridLayout l'écraserait à zéro.
      Layout.minimumHeight: choixFiltre.height

      selectedIndex: 0
      model: [qsTr("Région"), qsTr("N° de plan d'eau"), qsTr("Zone personnalisée"), qsTr("Code d'UE")]

      onItemSelected: function (index, modelData) {
        fenetre.modeFiltre = fenetre.modesFiltre[index];
      }
    }

    // ---- Région ----------------------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      visible: fenetre.modeFiltre === "region"
      text: qsTr("Région administrative")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ComboBox {
      id: comboRegion

      Layout.fillWidth: true
      visible: fenetre.modeFiltre === "region"

      textRole: "nom"
      valueRole: "code"
      currentIndex: -1
      model: fenetre.referentiels ? fenetre.referentiels.regions : []
    }

    // ---- N° de plan d'eau --------------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      visible: fenetre.modeFiltre === "lce"
      text: qsTr("N° du plan d'eau (LCE)")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    TextField {
      id: champLce

      Layout.fillWidth: true
      visible: fenetre.modeFiltre === "lce"

      maximumLength: 8
      placeholderText: qsTr("ex. 12777")
      inputMethodHints: Qt.ImhDigitsOnly
      validator: IntValidator {}
      onAccepted: fenetre.lancerRecherche()
    }

    // ---- Code d'UE ---------------------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      visible: fenetre.modeFiltre === "code"
      text: qsTr("Code de l'unité")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: fenetre.modeFiltre === "code"
      spacing: 2

      TextField {
        id: champCode

        Layout.fillWidth: true
        font: Theme.strongFont
        placeholderText: qsTr("ex. 02-12777-IPE")
        inputMethodHints: Qt.ImhUppercaseOnly
        onAccepted: fenetre.lancerRecherche()
      }

      Label {
        Layout.fillWidth: true
        text: qsTr("Format : région – n° de plan d'eau – type d'UE")
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

      visible: fenetre.modeFiltre === "emprise"

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
    ColumnLayout {
      Layout.fillWidth: true
      Layout.topMargin: 30
      Layout.bottomMargin: 30
      visible: service.enCours
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

      visible: !service.enCours && fenetre.unites.length > 0

      lignes: fenetre.unites
      accent: fenetre.accent

      onOuvrirVerrouille: function (unite) {
        fenetre.ouvrirUnite(unite, true);
      }
      onOuvrirLecture: function (unite) {
        fenetre.ouvrirUnite(unite, false);
      }
      onSupprimer: function (unite) {
        fenetre.demanderSuppression(unite);
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

    referentiels: fenetre.referentiels

    onResultats: function (lignes) {
      fenetre.unites = lignes;
      fenetre.messageErreur = "";
    }

    onEchec: function (message) {
      fenetre.unites = [];
      fenetre.messageErreur = message;
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

  function filtreCourant() {
    if (modeFiltre === "region")
      return {
        "mode": "region",
        "valeur": comboRegion.currentValue
      };

    if (modeFiltre === "lce")
      return {
        "mode": "lce",
        "valeur": champLce.text
      };

    if (modeFiltre === "code")
      return {
        "mode": "code",
        "valeur": champCode.text.trim().toUpperCase()
      };

    return {
      "mode": "emprise",
      "wkt": empriseWkt,
      "bbox": empriseBbox
    };
  }

  function resumeFiltre() {
    if (modeFiltre === "region")
      return qsTr("Région : %1").arg(comboRegion.currentIndex >= 0 ? comboRegion.currentText : "—");
    if (modeFiltre === "lce")
      return qsTr("Plan d'eau n° %1").arg(champLce.text);
    if (modeFiltre === "code")
      return qsTr("Code d'UE : %1").arg(champCode.text.trim().toUpperCase());
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
  // TODO : à brancher sur le point d'accès QFieldCloud (voir ServiceUE.qml).
  //   * verrouiller  → POST .../unites/<code>/verrou/  puis ouverture du
  //                    formulaire « mesurage » en écriture ;
  //   * consulter    → ouverture du même formulaire en lecture seule ;
  //   * supprimer    → DELETE .../unites/<code>/.
  function ouvrirUnite(unite, avecVerrou) {
    referentiels.definirVariableProjet("une_code_ident", unite["une_code_ident"]);

    if (avecVerrou) {
      avertir(qsTr("Ouverture verrouillée de %1 — service non déployé.").arg(unite["une_code_ident"]), "info");
    } else {
      avertir(qsTr("Ouverture en consultation de %1 — service non déployé.").arg(unite["une_code_ident"]), "info");
    }

    iface.logMessage("[IFA] ouvrir " + unite["une_code_ident"] + (avecVerrou ? " (avec verrou)" : " (lecture seule)"));
  }

  function demanderSuppression(unite) {
    confirmationSuppression.unite = unite;
    confirmationSuppression.open();
  }

  function supprimerUnite(unite) {
    if (!unite)
      return;

    // Retrait local, le temps que le service de suppression existe.
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
