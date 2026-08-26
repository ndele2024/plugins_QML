// =============================================================================
//  IfaCommande — une ligne de commande cliquable dans le menu
// =============================================================================
//  Rendu :
//
//    ┌──────────────────────────────────────────────────┐
//    │  ▢   Créer une UE                              › │
//    │      Nouvelle unité : région, projet, type…      │
//    └──────────────────────────────────────────────────┘
//
//  Hauteur minimale de 64 px : cible tactile confortable avec des gants, sur le
//  terrain. Le texte passe à la ligne plutôt que d'être tronqué.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

ItemDelegate {
  id: commande

  // ---------------------------------------------------------------------------
  //  API publique
  // ---------------------------------------------------------------------------
  property string titre: ""
  property string soustitre: ""
  property string icone: ""
  property color accent: Theme.mainColor

  // Affiche un fin séparateur au-dessus de la ligne (pour les lignes suivantes
  // d'une même section).
  property bool separateur: false

  // Une commande non encore implémentée reste cliquable — elle affiche alors
  // un bandeau « en cours de développement » — mais elle est signalée ici.
  property bool disponible: true

  // Cible tactile d'au moins 64 px, quel que soit le contenu.
  leftPadding: 14
  rightPadding: 10
  topPadding: 10
  bottomPadding: 10
  implicitHeight: Math.max(64, ligne.implicitHeight + topPadding + bottomPadding)
  focusPolicy: Qt.NoFocus

  background: Rectangle {
    color: commande.down ? Qt.rgba(commande.accent.r, commande.accent.g, commande.accent.b, 0.18) : commande.hovered ? Qt.rgba(commande.accent.r, commande.accent.g, commande.accent.b, 0.08) : "transparent"

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }

    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 68
      height: 1
      visible: commande.separateur
      color: Theme.controlBorderColor
    }
  }

  // Pas d'`anchors` ici : le Control positionne lui-même son contentItem à
  // partir des marges définies ci-dessus.
  contentItem: RowLayout {
    id: ligne

    spacing: 14

    // ---- Pastille d'icône ----------------------------------------------------
    Rectangle {
      Layout.preferredWidth: 40
      Layout.preferredHeight: 40
      Layout.alignment: Qt.AlignVCenter

      radius: 12
      color: Qt.rgba(commande.accent.r, commande.accent.g, commande.accent.b, 0.16)

      IconImage {
        anchors.centerIn: parent
        width: 22
        height: 22
        source: commande.icone !== "" ? Theme.getThemeVectorIcon(commande.icone) : ""
        color: commande.accent
        sourceSize: Qt.size(44, 44)
      }
    }

    // ---- Libellés ------------------------------------------------------------
    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 2

      Label {
        Layout.fillWidth: true
        text: commande.titre
        font: Theme.strongFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }

      Label {
        Layout.fillWidth: true
        visible: commande.soustitre !== ""
        text: commande.soustitre
        font: Theme.tinyFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }
    }

    // ---- Pastille « à venir » ------------------------------------------------
    Rectangle {
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: etiquetteAVenir.implicitWidth + 14
      Layout.preferredHeight: etiquetteAVenir.implicitHeight + 6
      visible: !commande.disponible

      radius: height / 2
      color: Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.18)

      Label {
        id: etiquetteAVenir
        anchors.centerIn: parent
        text: qsTr("à venir")
        font: Theme.tinyFont
        color: Theme.warningColor
      }
    }

    // ---- Chevron -------------------------------------------------------------
    IconImage {
      Layout.preferredWidth: 20
      Layout.preferredHeight: 20
      Layout.alignment: Qt.AlignVCenter
      source: Theme.getThemeVectorIcon("ic_chevron_right_white_24dp")
      color: Theme.secondaryTextColor
      opacity: 0.7
      sourceSize: Qt.size(40, 40)
    }
  }
}
