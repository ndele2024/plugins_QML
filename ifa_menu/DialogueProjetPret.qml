// =============================================================================
//  DialogueProjetPret — le projet à ouvrir, nommé, et qui reste à l'écran
// =============================================================================
//  Dernier geste des deux parcours « Créer une UE » et « Consulter une UE » :
//  le serveur a préparé un projet, QField ne l'ouvre pas de lui-même, et c'est
//  au technicien d'aller le chercher dans l'écran « Projets ».
//
//  ---------------------------------------------------------------------------
//  POURQUOI PAS UN TOAST
//  ---------------------------------------------------------------------------
//  Ce message était un toast. Un toast s'efface tout seul au bout de quelques
//  secondes — et il arrive précisément au moment où la fenêtre du plugin se
//  referme et où la carte réapparaît, c'est-à-dire là où le regard n'est pas.
//  Le technicien perdait donc le **nom du projet**, la seule information dont
//  il a besoin pour retrouver son travail : sans elle, il doit deviner lequel
//  des projets de la liste est le sien.
//
//  D'où un dialogue modal, qui ne se ferme que sur un geste explicite. Le nom
//  du projet y est détaché du reste du texte, dans son propre cadre : c'est ce
//  qu'il faut lire, retenir et retrouver.
//
//  ---------------------------------------------------------------------------
//  DEUX ÉTATS
//  ---------------------------------------------------------------------------
//  Le projet peut être packagé et déjà disponible, ou en cours de préparation
//  sur le serveur — c'est le cas quand l'attente du packaging a expiré côté
//  plugin sans que le travail soit fini. Le geste demandé est le même dans les
//  deux cas, le moment ne l'est pas : `paquetPret` change le titre et la
//  marche à suivre. Annoncer « prêt » pour un projet absent de la liste
//  enverrait le technicien chercher pour rien, et lui ferait douter du reste
//  de ce que dit le plugin.
//
//  ---------------------------------------------------------------------------
//  USAGE
//  ---------------------------------------------------------------------------
//      DialogueProjetPret {
//        id: dialogueProjet
//        zoneParente: fenetre.zoneUtile
//        accent: fenetre.accent
//      }
//
//      dialogueProjet.annoncer(nomProjet, qsTr("Unité 02-12777-IPE créée."));
//      dialogueProjet.annoncer(nomProjet, texte, false);   // paquet en cours
//
//  ⚠️ `zoneParente` doit être la zone utile de la fenêtre hôte (le
//  `contentItem` de la fenêtre principale de QField), jamais la fenêtre du
//  plugin elle-même : « Créer une UE » se referme au moment où le projet est
//  prêt, et un dialogue posé dans cette fenêtre disparaîtrait avec elle.
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
  // Zone dans laquelle centrer le dialogue — `zoneUtile` de l'IfaPopup hôte.
  property Item zoneParente: null

  property color accent: Theme.cloudColor

  // Nom du projet QFieldCloud à ouvrir.
  property string nomProjet: ""

  // Ce qui vient d'être fait, en une phrase. Propre à la fenêtre appelante :
  // une unité créée et verrouillée n'est pas la même nouvelle qu'une unité
  // ouverte en consultation.
  property string message: ""

  // Le paquet du projet est-il fait, ou le serveur y travaille-t-il encore ?
  // Le geste demandé est le même, le moment ne l'est pas : annoncer « prêt »
  // pour un projet qui n'est pas encore dans la liste enverrait le technicien
  // chercher pour rien, et lui ferait douter du reste.
  property bool paquetPret: true

  // `pret` est facultatif : les appelants qui n'ont que des projets déjà
  // packagés à annoncer n'ont pas à s'en soucier.
  function annoncer(nom, texte, pret) {
    nomProjet = "" + (nom ? nom : "");
    message = "" + (texte ? texte : "");
    paquetPret = pret === undefined ? true : !!pret;
    open();
  }

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

  // Ni clic à côté ni glissement ne le referment : il n'y a qu'un bouton pour
  // cela. Le message n'a d'intérêt que lu, et un geste de trop sur un écran
  // tactile l'effacerait avant même qu'il ne soit vu.
  closePolicy: Popup.CloseOnEscape

  background: Rectangle {
    color: Theme.mainBackgroundColor
    radius: 14
    border.width: 1
    border.color: Theme.controlBorderColor
  }

  contentItem: ColumnLayout {
    spacing: 12

    // ---- Titre ---------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 18
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      spacing: 10

      IconImage {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        Layout.alignment: Qt.AlignVCenter
        source: Theme.getThemeVectorIcon(dialogue.paquetPret ? "ic_check_white_24dp" : "ic_alert_black_24dp")
        color: dialogue.paquetPret ? Theme.goodColor : Theme.warningColor
        sourceSize: Qt.size(48, 48)
      }

      Label {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: dialogue.paquetPret ? qsTr("Projet prêt à ouvrir") : qsTr("Projet en cours de préparation")
        font: Theme.strongFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }
    }

    // ---- Ce qui vient d'être fait ---------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      visible: dialogue.message !== ""
      text: dialogue.message
      font: Theme.tipFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    // ---- Le nom du projet ------------------------------------------------------
    //  Détaché du texte : c'est la seule chose à retenir de ce dialogue.
    Rectangle {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      Layout.preferredHeight: nomAfficher.implicitHeight + 24

      radius: 10
      color: Qt.rgba(dialogue.accent.r, dialogue.accent.g, dialogue.accent.b, 0.12)
      border.width: 1
      border.color: Qt.rgba(dialogue.accent.r, dialogue.accent.g, dialogue.accent.b, 0.4)

      Label {
        id: nomAfficher

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        horizontalAlignment: Text.AlignHCenter
        text: dialogue.nomProjet
        font: Theme.strongFont
        color: dialogue.accent
        wrapMode: Text.WrapAnywhere
      }
    }

    // ---- La marche à suivre -----------------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      text: dialogue.paquetPret ? qsTr("Ouvrez ce projet depuis l'écran « Projets » de QField. Votre projet actuel reste ouvert : rien n'a été fermé ni remplacé.") : qsTr("Le serveur prépare encore ce projet. Il apparaîtra sous ce nom dans l'écran « Projets » de QField : rafraîchissez la liste dans quelques minutes. Votre projet actuel reste ouvert.")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    // ---- Sortie -------------------------------------------------------------------
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
        text: qsTr("J'ai compris")
        bgcolor: dialogue.accent
        color: (0.299 * dialogue.accent.r + 0.587 * dialogue.accent.g + 0.114 * dialogue.accent.b) > 0.6 ? Theme.darkGray : "#ffffff"
        onClicked: dialogue.close()
      }
    }
  }
}
