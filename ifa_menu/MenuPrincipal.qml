// =============================================================================
//  MenuPrincipal — la fenêtre de menu du plugin IFA 2.0
// =============================================================================
//  Cette fenêtre ne connaît AUCUNE commande en particulier : elle affiche le
//  contenu du tableau `sections` que lui fournit main.qml, et émet le signal
//  `commandeChoisie` quand l'utilisateur en active une.
//
//  Conséquence : ajouter un menu ou une commande ne demande jamais de modifier
//  ce fichier — uniquement le registre `sections` de main.qml.
//
//  Structure attendue d'une section :
//
//    {
//      id:        "ue",                             // identifiant interne
//      titre:     "Gestionnaire d'unité…",          // titre affiché
//      soustitre: "Unités d'échantillonnage",       // ligne secondaire
//      icone:     "ic_geometry_point_24dp",         // icône du thème QField
//      accent:    "cloudColor",                     // nom d'une couleur Theme
//      commandes: [ { id, titre, soustitre, icone, fichier }, … ]
//    }
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

IfaPopup {
  id: menu

  titre: qsTr("IFA 2.0")
  soustitre: qsTr("Inventaire de la faune aquatique")
  icone: "ic_3x3_grid_white_24dp"
  margeContenu: 12

  // Registre fourni par main.qml.
  property var sections: []

  // Émis avec l'objet « commande » complet (voir structure ci-dessus).
  signal commandeChoisie(var commande)

  Repeater {
    model: menu.sections

    delegate: Rectangle {
      id: carte

      // On capture le `modelData` de la section : le Repeater imbriqué des
      // commandes redéfinit `modelData` dans sa propre portée.
      readonly property var section: modelData

      // La couleur d'accent est désignée par son nom dans le thème QField afin
      // de suivre automatiquement le passage en thème sombre.
      readonly property color accent: section.accent && Theme[section.accent] !== undefined ? Theme[section.accent] : Theme.mainColor

      Layout.fillWidth: true
      Layout.bottomMargin: 4

      implicitHeight: contenuCarte.implicitHeight
      radius: 14
      color: Theme.controlBackgroundAlternateColor
      border.width: 1
      border.color: Theme.controlBorderColor
      clip: true

      ColumnLayout {
        id: contenuCarte

        width: carte.width
        spacing: 0

        // ---- Bandeau de section ----------------------------------------------
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: enteteSection.implicitHeight + 22

          color: Qt.rgba(carte.accent.r, carte.accent.g, carte.accent.b, 0.10)

          // Liseré vertical accentué, à gauche.
          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 4
            color: carte.accent
          }

          RowLayout {
            id: enteteSection

            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 14
            spacing: 12

            IconImage {
              Layout.preferredWidth: 22
              Layout.preferredHeight: 22
              Layout.alignment: Qt.AlignVCenter
              source: carte.section.icone ? Theme.getThemeVectorIcon(carte.section.icone) : ""
              color: carte.accent
              sourceSize: Qt.size(44, 44)
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Label {
                Layout.fillWidth: true
                text: carte.section.titre
                font: Theme.strongTipFont
                color: carte.accent
                wrapMode: Text.WordWrap
              }

              Label {
                Layout.fillWidth: true
                visible: !!carte.section.soustitre
                text: carte.section.soustitre ? carte.section.soustitre : ""
                font: Theme.tinyFont
                color: Theme.secondaryTextColor
                wrapMode: Text.WordWrap
              }
            }
          }
        }

        // ---- Commandes de la section -----------------------------------------
        Repeater {
          model: carte.section.commandes

          delegate: IfaCommande {
            Layout.fillWidth: true

            accent: carte.accent
            titre: modelData.titre
            soustitre: modelData.soustitre ? modelData.soustitre : ""
            icone: modelData.icone ? modelData.icone : ""
            disponible: !!modelData.fichier
            separateur: index > 0

            onClicked: menu.commandeChoisie(modelData)
          }
        }
      }
    }
  }

  // ---- Pied de page : rappel du projet courant ---------------------------------
  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: rappelProjet.implicitHeight + 8

    Label {
      id: rappelProjet

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter

      horizontalAlignment: Text.AlignHCenter
      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
      text: {
        if (typeof qgisProject === "undefined" || !qgisProject || qgisProject.fileName === "")
          return qsTr("Aucun projet ouvert");
        return qsTr("Projet : %1").arg(qgisProject.title !== "" ? qgisProject.title : qgisProject.baseName);
      }
    }
  }
}
