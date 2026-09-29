// =============================================================================
//  DialogueMiseAJour — proposer la nouvelle version du plugin
// =============================================================================
//  Proposer, pas imposer : une mise à jour en pleine saisie n'est jamais le
//  bon moment, et elle recharge le plugin — les fenêtres ouvertes se ferment.
//  « Plus tard » ne revient qu'au prochain démarrage de QField.
//
//  Usage (main.qml) :
//
//      DialogueMiseAJour {
//        id: dialogueMiseAJour
//        onAccepte: serviceMiseAJour.installer()
//      }
//      dialogueMiseAJour.proposer("0.1.0", "0.2.0");
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import Theme

Popup {
  id: dialogue

  // ---------------------------------------------------------------------------
  //  API
  // ---------------------------------------------------------------------------
  property string versionInstallee: ""
  property string versionPubliee: ""
  property color accent: Theme.mainColor

  signal accepte

  function proposer(installee, publiee) {
    versionInstallee = "" + installee;
    versionPubliee = "" + publiee;

    // Même piège que les autres dialogues de main.qml : la fenêtre principale
    // n'existait pas à la construction du plugin.
    if (!zoneParente && iface.mainWindow())
      zoneParente = iface.mainWindow().contentItem;

    open();
  }

  // ---------------------------------------------------------------------------
  //  Présentation
  // ---------------------------------------------------------------------------
  property Item zoneParente: iface.mainWindow() ? iface.mainWindow().contentItem : null

  parent: zoneParente
  width: Math.min(parent ? parent.width - 40 : 340, 420)
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
    spacing: 12

    Label {
      Layout.fillWidth: true
      Layout.topMargin: 18
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      text: qsTr("Mise à jour du plugin IFA 2.0")
      font: Theme.strongFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      text: qsTr("La version %1 est disponible. Vous utilisez la version %2.").arg(dialogue.versionPubliee).arg(dialogue.versionInstallee)
      font: Theme.defaultFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      text: qsTr("L'installation prend quelques secondes et recharge le plugin : les fenêtres IFA ouvertes se ferment. Votre projet et vos données ne sont pas touchés.")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.bottomMargin: 14
      Layout.leftMargin: 12
      Layout.rightMargin: 12
      Layout.topMargin: 4
      spacing: 8

      Item {
        Layout.fillWidth: true
      }

      QfButton {
        text: qsTr("Plus tard")
        bgcolor: "transparent"
        color: Theme.secondaryTextColor
        onClicked: dialogue.close()
      }

      QfButton {
        text: qsTr("Installer")
        bgcolor: dialogue.accent
        color: (0.299 * dialogue.accent.r + 0.587 * dialogue.accent.g + 0.114 * dialogue.accent.b) > 0.6 ? Theme.darkGray : "#ffffff"
        onClicked: {
          dialogue.close();
          dialogue.accepte();
        }
      }
    }
  }
}
