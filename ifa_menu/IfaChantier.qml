// =============================================================================
//  IfaChantier — bandeau « fonction en cours de développement »
// =============================================================================
//  Utilisé par les fenêtres encore vides, pour qu'une commande du menu réponde
//  toujours quelque chose d'explicite plutôt que d'ouvrir un écran blanc.
//
//    IfaChantier {
//      Layout.fillWidth: true
//      accent: fenetre.accent
//      description: qsTr("Cette fenêtre permettra de …")
//      etapes: [ qsTr("…"), qsTr("…") ]
//    }
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

ColumnLayout {
  id: chantier

  property color accent: Theme.mainColor
  property string description: ""

  // Liste de chaînes : ce qu'il reste à faire, affiché sous forme de puces.
  property var etapes: []

  spacing: 14

  // ---- Pictogramme ------------------------------------------------------------
  Rectangle {
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: 18
    Layout.preferredWidth: 72
    Layout.preferredHeight: 72

    radius: width / 2
    color: Qt.rgba(chantier.accent.r, chantier.accent.g, chantier.accent.b, 0.14)

    IconImage {
      anchors.centerIn: parent
      width: 34
      height: 34
      source: Theme.getThemeVectorIcon("ic_processing_black_24dp")
      color: chantier.accent
      sourceSize: Qt.size(68, 68)
    }
  }

  Label {
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
    text: qsTr("Fonction en cours de développement")
    font: Theme.strongFont
    color: Theme.mainTextColor
    wrapMode: Text.WordWrap
  }

  Label {
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    visible: chantier.description !== ""
    horizontalAlignment: Text.AlignHCenter
    text: chantier.description
    font: Theme.tipFont
    color: Theme.secondaryTextColor
    wrapMode: Text.WordWrap
  }

  // ---- Étapes prévues ---------------------------------------------------------
  Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 6
    Layout.preferredHeight: listeEtapes.implicitHeight + 28

    visible: chantier.etapes.length > 0

    radius: 12
    color: Theme.controlBackgroundAlternateColor
    border.width: 1
    border.color: Theme.controlBorderColor

    ColumnLayout {
      id: listeEtapes

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 8

      Label {
        Layout.fillWidth: true
        text: qsTr("Prochaines étapes")
        font: Theme.strongTipFont
        color: chantier.accent
      }

      Repeater {
        model: chantier.etapes

        delegate: RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 6
            width: 6
            height: 6
            radius: 3
            color: chantier.accent
          }

          Label {
            Layout.fillWidth: true
            text: modelData
            font: Theme.tinyFont
            color: Theme.mainTextColor
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
