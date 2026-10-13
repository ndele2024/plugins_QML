// =============================================================================
//  DialogueAlerte — une information qui demande d'être lue
// =============================================================================
//  Pour ce qu'une notification passagère ferait manquer : un refus et sa
//  raison (« Seul le créateur du projet ou un administrateur peut le
//  supprimer »). La fenêtre reste jusqu'à « Compris ».
//
//  Usage :
//
//      DialogueAlerte { id: alerte; zoneParente: fenetre.zoneUtile }
//      alerte.afficher(qsTr("Suppression impossible"), raison, Theme.warningColor);
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

Popup {
  id: dialogue

  property Item zoneParente: null

  property string titre: ""
  property string message: ""
  property color teinte: Theme.warningColor

  function afficher(nouveauTitre, nouveauMessage, nouvelleTeinte) {
    titre = nouveauTitre;
    message = nouveauMessage;
    teinte = nouvelleTeinte !== undefined ? nouvelleTeinte : Theme.warningColor;
    open();
  }

  parent: zoneParente
  width: Math.min(parent ? parent.width - 40 : 340, 440)
  x: parent ? (parent.width - width) / 2 : 0
  y: parent ? (parent.height - height) / 2 : 0

  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  background: Rectangle {
    color: Theme.mainBackgroundColor
    radius: 14
    border.width: 1
    border.color: Qt.rgba(dialogue.teinte.r, dialogue.teinte.g, dialogue.teinte.b, 0.6)
  }

  contentItem: ColumnLayout {
    spacing: 12

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 18
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      spacing: 10

      IconImage {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignTop
        source: Theme.getThemeVectorIcon("ic_alert_black_24dp")
        color: dialogue.teinte
        sourceSize: Qt.size(48, 48)
      }

      Label {
        Layout.fillWidth: true
        text: dialogue.titre
        font: Theme.strongFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: dialogue.message
      font: Theme.tipFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.bottomMargin: 14
      Layout.leftMargin: 12
      Layout.rightMargin: 12

      Item {
        Layout.fillWidth: true
      }

      QfButton {
        text: qsTr("Compris")
        onClicked: dialogue.close()
      }
    }
  }
}
