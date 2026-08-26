// =============================================================================
//  IfaPopup — coquille commune à toutes les fenêtres du plugin IFA 2.0
// =============================================================================
//  Fournit, pour ne pas le réécrire dans chaque fenêtre :
//    * un dimensionnement responsive : plein écran sur téléphone, carte centrée
//      sur tablette / ordinateur ;
//    * un en-tête coloré (icône, titre, sous-titre, bouton de fermeture) ;
//    * une zone de contenu défilante ;
//    * une barre d'actions optionnelle en pied de fenêtre ;
//    * un raccourci `avertir()` vers les notifications de QField.
//
//  Utilisation :
//
//    IfaPopup {
//      titre: qsTr("Ma fenêtre")
//      icone: "ic_add_white_24dp"
//
//      Label { Layout.fillWidth: true; text: "…" }   // <- contenu par défaut
//
//      actions: [
//        QfButton { text: qsTr("Annuler"); onClicked: close() }
//      ]
//    }
//
//  Le contenu est empilé dans un ColumnLayout : utiliser les propriétés
//  attachées `Layout.*` (Layout.fillWidth, Layout.topMargin, …) sur chaque
//  enfant.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

Popup {
  id: fenetre

  // ---------------------------------------------------------------------------
  //  API publique
  // ---------------------------------------------------------------------------
  property string titre: ""
  property string soustitre: ""
  property string icone: ""

  // Couleur d'accent de la fenêtre (en-tête, liserés). Une couleur du thème
  // QField est préférable à une valeur codée en dur : elle reste lisible en
  // thème clair comme en thème sombre.
  property color accent: Theme.mainColor

  // Données de référence partagées, injectées par main.qml (Referentiels.qml).
  property var referentiels: null

  // Contenu principal de la fenêtre.
  default property alias contenu: colonne.data

  // Boutons du pied de page. Le pied reste masqué tant qu'il est vide.
  property alias actions: pied.data

  // Marge intérieure de la zone de contenu.
  property real margeContenu: 16

  // Largeur maximale sur grand écran. À augmenter pour une fenêtre qui affiche
  // un tableau plutôt qu'un formulaire.
  property real largeurMax: 560

  // ---------------------------------------------------------------------------
  //  Dimensionnement responsive
  // ---------------------------------------------------------------------------
  // Le `contentItem` de la fenêtre principale correspond à la surface
  // réellement utilisable de QField.
  //
  // Non `readonly` à dessein : si la fenêtre principale n'était pas encore
  // construite au chargement du plugin, `onAboutToShow` rattrape le coup —
  // `iface.mainWindow()` n'étant pas une propriété, la liaison ne se
  // réévaluerait jamais d'elle-même.
  property Item zoneUtile: iface.mainWindow() ? iface.mainWindow().contentItem : null

  onAboutToShow: {
    if (!zoneUtile && iface.mainWindow()) {
      zoneUtile = iface.mainWindow().contentItem;
    }
  }

  // En dessous de 520 px de large (téléphone en portrait), la fenêtre occupe
  // tout l'écran : plus confortable au doigt, et pas de formulaire comprimé.
  readonly property bool compact: zoneUtile ? zoneUtile.width < 520 : true

  // Contraste automatique du texte posé sur la couleur d'accent : indispensable,
  // car les accents clairs du thème QField (vert #80cc28) rendraient un texte
  // blanc illisible.
  readonly property color surAccent: (0.299 * accent.r + 0.587 * accent.g + 0.114 * accent.b) > 0.6 ? Theme.darkGray : "#ffffff"

  parent: zoneUtile
  width: !zoneUtile ? 0 : (compact ? zoneUtile.width : Math.min(zoneUtile.width * 0.9, largeurMax))
  height: !zoneUtile ? 0 : (compact ? zoneUtile.height : Math.min(zoneUtile.height * 0.92, 760))
  x: zoneUtile ? (zoneUtile.width - width) / 2 : 0
  y: zoneUtile ? (zoneUtile.height - height) / 2 : 0

  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape

  // ---------------------------------------------------------------------------
  //  Animations d'ouverture / fermeture
  // ---------------------------------------------------------------------------
  enter: Transition {
    ParallelAnimation {
      NumberAnimation {
        property: "opacity"
        from: 0
        to: 1
        duration: 160
        easing.type: Easing.OutCubic
      }
      NumberAnimation {
        property: "scale"
        from: 0.97
        to: 1
        duration: 160
        easing.type: Easing.OutCubic
      }
    }
  }

  exit: Transition {
    NumberAnimation {
      property: "opacity"
      from: 1
      to: 0
      duration: 120
      easing.type: Easing.InCubic
    }
  }

  background: Rectangle {
    color: Theme.mainBackgroundColor
    radius: fenetre.compact ? 0 : 16
    border.width: fenetre.compact ? 0 : 1
    border.color: Theme.controlBorderColor
  }

  // ---------------------------------------------------------------------------
  //  Structure : en-tête / contenu défilant / pied de page
  // ---------------------------------------------------------------------------
  contentItem: ColumnLayout {
    spacing: 0

    // ---- En-tête -------------------------------------------------------------
    Rectangle {
      id: entete

      Layout.fillWidth: true
      Layout.preferredHeight: ligneEntete.implicitHeight + 24

      color: fenetre.accent
      radius: fenetre.compact ? 0 : 16

      // Un Rectangle arrondit ses quatre coins : on recouvre les deux coins du
      // bas pour obtenir un bandeau arrondi uniquement en haut.
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.radius
        color: parent.color
        visible: parent.radius > 0
      }

      RowLayout {
        id: ligneEntete

        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 6
        spacing: 12

        IconImage {
          Layout.preferredWidth: 26
          Layout.preferredHeight: 26
          Layout.alignment: Qt.AlignVCenter
          visible: fenetre.icone !== ""
          source: fenetre.icone !== "" ? Theme.getThemeVectorIcon(fenetre.icone) : ""
          color: fenetre.surAccent
          sourceSize: Qt.size(52, 52)
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 1

          Label {
            Layout.fillWidth: true
            text: fenetre.titre
            font: Theme.strongTitleFont
            color: fenetre.surAccent
            elide: Text.ElideRight
          }

          Label {
            Layout.fillWidth: true
            visible: fenetre.soustitre !== ""
            text: fenetre.soustitre
            font: Theme.tinyFont
            color: fenetre.surAccent
            opacity: 0.8
            elide: Text.ElideRight
          }
        }

        QfToolButton {
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: 2
          width: 40
          height: 40
          round: true
          bgcolor: "transparent"
          iconSource: Theme.getThemeVectorIcon("ic_close_white_24dp")
          iconColor: fenetre.surAccent
          onClicked: fenetre.close()
        }
      }
    }

    // ---- Contenu défilant ----------------------------------------------------
    Flickable {
      id: zoneDefilante

      Layout.fillWidth: true
      Layout.fillHeight: true

      clip: true
      contentWidth: width
      contentHeight: colonne.implicitHeight + 2 * fenetre.margeContenu
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick

      ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
      }

      ColumnLayout {
        id: colonne

        x: fenetre.margeContenu
        y: fenetre.margeContenu
        width: zoneDefilante.width - 2 * fenetre.margeContenu
        spacing: 10
      }
    }

    // ---- Pied de page --------------------------------------------------------
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: lignePied.implicitHeight + 20

      visible: pied.children.length > 0

      color: Theme.controlBackgroundAlternateColor

      Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.controlBorderColor
      }

      RowLayout {
        id: lignePied

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        // Pousse les boutons vers la droite. L'espaceur est volontairement
        // placé en dehors de `pied` : affecter une liste à `actions` remplace
        // le contenu de `pied.data`, et emporterait l'espaceur avec lui.
        Item {
          Layout.fillWidth: true
        }

        RowLayout {
          id: pied

          spacing: 8
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Utilitaires disponibles dans toutes les fenêtres dérivées
  // ---------------------------------------------------------------------------
  // Affiche une notification QField. `type` : "info" (défaut), "warning",
  // "error". Retombe sur le journal si la fenêtre principale est indisponible.
  function avertir(message, type) {
    const principale = iface.mainWindow();
    if (principale && typeof principale.displayToast === "function") {
      principale.displayToast(message, type ? type : "info");
    } else {
      iface.logMessage("[IFA] " + message);
    }
  }
}
