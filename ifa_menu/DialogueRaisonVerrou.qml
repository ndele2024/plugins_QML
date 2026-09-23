// =============================================================================
//  DialogueRaisonVerrou — motif du verrouillage d'une unité d'échantillonnage
// =============================================================================
//  Verrouiller une unité la retire aux autres équipes : la raison saisie ici
//  est ce qu'elles liront en tentant de l'ouvrir. C'est la seule information
//  qui leur permette de savoir à qui s'adresser, et c'est pourquoi elle est
//  exigée plutôt que suggérée.
//
//  Le motif est écrit dans `unite_echan.une_raiso_verro` (500 caractères), avec
//  la date du verrou et le nom de son détenteur.
//
//  Usage :
//
//      DialogueRaisonVerrou {
//        id: dialogueRaison
//        zoneParente: fenetre.zoneUtile
//        onValide: function (raison) { … }
//      }
//
//      dialogueRaison.demander(unite);
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

Popup {
  id: dialogue

  // ---------------------------------------------------------------------------
  //  API
  // ---------------------------------------------------------------------------
  // Zone dans laquelle centrer la fenêtre — `zoneUtile` de l'IfaPopup hôte.
  property Item zoneParente: null

  // Unité concernée, telle que la recherche l'a rendue.
  property var unite: null

  // Longueur déclarée de `une_raiso_verro` dans le schéma métier.
  readonly property int longueurMax: 500

  // Motifs les plus courants, proposés d'un geste : sur un téléphone, au bord
  // d'un lac, taper une phrase est ce qui coûte le plus cher.
  property var suggestions: [qsTr("Modifier en toute sécurité"), qsTr("Empêcher la modification par d'autres utilisateurs"), qsTr("Saisie des données de terrain en cours"), qsTr("Correction d'un inventaire existant")]

  signal valide(string raison)

  function demander(uniteDemandee) {
    unite = uniteDemandee;
    champRaison.text = "";
    open();
    champRaison.forceActiveFocus();
  }

  readonly property string raisonSaisie: champRaison.text.trim()
  readonly property bool raisonSuffisante: raisonSaisie.length > 0

  // ---------------------------------------------------------------------------
  //  Présentation
  // ---------------------------------------------------------------------------
  parent: zoneParente
  width: Math.min(parent ? parent.width - 40 : 340, 460)
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
      text: dialogue.unite ? qsTr("Verrouiller l'unité %1").arg(dialogue.unite["une_code_ident"]) : qsTr("Verrouiller l'unité")
      font: Theme.strongFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: qsTr("L'unité vous sera réservée jusqu'à son déverrouillage. Indiquez pourquoi : les autres équipes liront ce motif si elles tentent de l'ouvrir.")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    TextField {
      id: champRaison

      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      placeholderText: qsTr("Raison du verrouillage")
      maximumLength: dialogue.longueurMax
      selectByMouse: true

      onAccepted: {
        if (dialogue.raisonSuffisante)
          dialogue.confirmer();
      }
    }

    // Les suggestions remplacent la saisie plutôt que de s'y ajouter : le
    // technicien qui en choisit une a fini, celui qui écrit n'est pas gêné.
    Flow {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      spacing: 6

      Repeater {
        model: dialogue.suggestions

        delegate: Rectangle {
          required property string modelData

          width: Math.min(etiquette.implicitWidth + 20, dialogue.width - 44)
          height: etiquette.implicitHeight + 12
          radius: height / 2
          color: souris.pressed ? Theme.controlBorderColor : "transparent"
          border.width: 1
          border.color: Theme.controlBorderColor

          Label {
            id: etiquette

            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: parent.modelData
            font: Theme.tipFont
            color: Theme.secondaryTextColor
            elide: Text.ElideRight
          }

          MouseArea {
            id: souris

            anchors.fill: parent
            onClicked: champRaison.text = parent.modelData
          }
        }
      }
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
        onClicked: dialogue.close()
      }

      QfButton {
        text: qsTr("Verrouiller et ouvrir")
        enabled: dialogue.raisonSuffisante
        onClicked: dialogue.confirmer()
      }
    }
  }

  function confirmer() {
    const raison = raisonSaisie;
    close();
    valide(raison);
  }
}
