// =============================================================================
//  DialogueTypeUe — ajouter un type d'UE à un projet, ou le modifier
// =============================================================================
//  Ajouter un type d'UE à un projet, c'est dire ce qu'on y planifie : le
//  nombre d'implantations et le nombre de remesurages. Les deux sont exigés —
//  au moins une implantation, zéro remesurage ou plus —, comme dans la table
//  `proje_type_unite_echan` qui les reçoit.
//
//  La fenêtre ne propose que les types pas encore ajoutés au projet : un type
//  ne figure qu'une fois par projet (clé primaire de la table). En
//  modification, le type est fixé et seuls les nombres changent.
//
//  Usage :
//
//      DialogueTypeUe {
//        id: dialogueType
//        zoneParente: fenetre.zoneUtile
//        onValide: function (typeUe) { … }
//      }
//
//      dialogueType.ajouter(typesRestants);          // [{ tue_code_ident, tue_nom }]
//      dialogueType.modifier(typeUe, [typeUe]);
//
//  `valide(typeUe)` rend { tue_code_ident, tue_nom, nb_impla_plani,
//  nb_remes_plani } — les nombres en entiers.
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

  property color accent: Theme.mainColor

  // Les types proposés dans la liste : ceux qui ne sont pas encore ajoutés,
  // ou le seul type modifié.
  property var typesProposes: []

  // Le type en modification, ou null pour un ajout.
  property var typeModifie: null
  readonly property bool modification: typeModifie !== null

  // Bornes du serveur et des contraintes de la table.
  readonly property int nbImplaMin: 1
  readonly property int nbRemesMin: 0
  readonly property int nbPlaniMax: 100000

  signal valide(var typeUe)

  function ajouter(types) {
    typeModifie = null;
    typesProposes = types;
    // Un seul type restant : rien à choisir.
    comboType.currentIndex = types.length === 1 ? 0 : -1;
    champImpla.text = "";
    champRemes.text = "";
    open();
    if (comboType.currentIndex >= 0)
      champImpla.forceActiveFocus();
  }

  function modifier(typeUe, types) {
    typeModifie = typeUe;
    typesProposes = types;
    comboType.currentIndex = comboType.indexOfValue(typeUe["tue_code_ident"]);
    champImpla.text = "" + typeUe["nb_impla_plani"];
    champRemes.text = "" + typeUe["nb_remes_plani"];
    open();
    champImpla.forceActiveFocus();
  }

  readonly property bool implaValide: nombreValide(champImpla.text, nbImplaMin)
  readonly property bool remesValide: nombreValide(champRemes.text, nbRemesMin)
  readonly property bool pret: comboType.currentIndex >= 0 && implaValide && remesValide

  // ---------------------------------------------------------------------------
  //  Présentation
  // ---------------------------------------------------------------------------
  parent: zoneParente
  width: Math.min(parent ? parent.width - 40 : 340, 460)
  x: parent ? (parent.width - width) / 2 : 0
  y: parent ? Math.max(20, (parent.height - height) / 2) : 0

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
    spacing: 10

    Label {
      Layout.fillWidth: true
      Layout.topMargin: 18
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: dialogue.modification ? qsTr("Modifier le type d'UE") : qsTr("Ajouter un type d'UE")
      font: Theme.strongFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: qsTr("Indiquez ce que le projet planifie pour ce type : le nombre d'implantations et le nombre de remesurages.")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    // ---- Type d'UE ---------------------------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.topMargin: 4
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: qsTr("Type d'UE") + " *"
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ComboBox {
      id: comboType

      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      // En modification, le type est la clé de la ligne : il ne change pas.
      // Pour changer de type, on retire celui-ci et on en ajoute un autre.
      enabled: !dialogue.modification

      textRole: "tue_nom"
      valueRole: "tue_code_ident"
      currentIndex: -1
      model: dialogue.typesProposes

      displayText: currentIndex === -1 ? qsTr("Choisir un type d'UE") : currentText

      onActivated: champImpla.forceActiveFocus()
    }

    // ---- Implantations -----------------------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.topMargin: 4
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: qsTr("Nombre d'implantations planifiées") + " *"
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    TextField {
      id: champImpla

      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      placeholderText: qsTr("au moins 1")
      maximumLength: 6
      inputMethodHints: Qt.ImhDigitsOnly
      validator: IntValidator {
        bottom: 0
        top: dialogue.nbPlaniMax
      }
      color: text === "" || dialogue.implaValide ? Theme.mainTextColor : Theme.errorColor

      onAccepted: champRemes.forceActiveFocus()
    }

    // ---- Remesurages -------------------------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.topMargin: 4
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: qsTr("Nombre de remesurages planifiés") + " *"
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    TextField {
      id: champRemes

      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      placeholderText: qsTr("0 si aucun remesurage")
      maximumLength: 6
      inputMethodHints: Qt.ImhDigitsOnly
      validator: IntValidator {
        bottom: 0
        top: dialogue.nbPlaniMax
      }
      color: text === "" || dialogue.remesValide ? Theme.mainTextColor : Theme.errorColor

      onAccepted: {
        if (dialogue.pret)
          dialogue.confirmer();
      }
    }

    // ---- Ce qui manque -----------------------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      visible: !dialogue.pret
      text: dialogue.manquant()
      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 4
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
        text: dialogue.modification ? qsTr("Enregistrer") : qsTr("Ajouter")
        enabled: dialogue.pret
        bgcolor: dialogue.accent
        onClicked: dialogue.confirmer()
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Fonctions
  // ---------------------------------------------------------------------------
  function nombreValide(texte, minimum) {
    const t = ("" + texte).trim();
    if (!/^[0-9]+$/.test(t))
      return false;
    const n = parseInt(t, 10);
    return n >= minimum && n <= nbPlaniMax;
  }

  function manquant() {
    if (comboType.currentIndex < 0)
      return qsTr("Choisissez un type d'UE.");
    if (!implaValide)
      return qsTr("Indiquez au moins %1 implantation (au plus %2).").arg(nbImplaMin).arg(nbPlaniMax);
    if (!remesValide)
      return qsTr("Indiquez le nombre de remesurages : 0 ou plus (au plus %1).").arg(nbPlaniMax);
    return "";
  }

  function confirmer() {
    if (!pret)
      return;

    const typeUe = {
      "tue_code_ident": "" + comboType.currentValue,
      "tue_nom": comboType.currentText,
      "nb_impla_plani": parseInt(champImpla.text, 10),
      "nb_remes_plani": parseInt(champRemes.text, 10)
    };

    close();
    valide(typeUe);
  }
}
