// =============================================================================
//  EtiquetteVerrou — pastille d'état de verrouillage d'une UE
// =============================================================================
//  Reflète la colonne `une_ind_verro` de la table `unite_echan` : « O » quand
//  l'unité est verrouillée, « N » sinon. Le détenteur du verrou
//  (`une_nom_propr_verro`) apparaît en infobulle.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl

import org.qfield
import Theme

Rectangle {
  id: etiquette

  property bool verrouillee: false
  property string detenteur: ""

  readonly property color teinte: verrouillee ? Theme.warningColor : Theme.secondaryTextColor

  implicitWidth: ligne.implicitWidth + 16
  implicitHeight: 24
  width: implicitWidth
  height: implicitHeight

  radius: height / 2
  color: Qt.rgba(teinte.r, teinte.g, teinte.b, 0.16)

  Row {
    id: ligne

    anchors.centerIn: parent
    spacing: 4

    IconImage {
      anchors.verticalCenter: parent.verticalCenter
      width: 13
      height: 13
      source: Theme.getThemeVectorIcon(etiquette.verrouillee ? "ic_lock_white_24dp" : "ic_lock_open_white_24dp")
      color: etiquette.teinte
      sourceSize: Qt.size(26, 26)
    }

    Label {
      anchors.verticalCenter: parent.verticalCenter
      text: etiquette.verrouillee ? qsTr("Verrouillée") : qsTr("Libre")
      font: Theme.tinyFont
      color: etiquette.teinte
    }
  }

  ToolTip.visible: zoneSurvol.containsMouse && etiquette.verrouillee && etiquette.detenteur !== ""
  ToolTip.text: qsTr("Verrouillée par %1").arg(etiquette.detenteur)

  MouseArea {
    id: zoneSurvol

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }
}
