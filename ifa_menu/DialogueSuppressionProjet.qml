// =============================================================================
//  DialogueSuppressionProjet — confirmer la suppression d'un projet
// =============================================================================
//  Supprimer un projet est définitif : le projet et ses types d'UE quittent la
//  base IFA. Le dialogue le dit, nomme ce qui part, et exige le **mot de passe**
//  de l'utilisateur — un appareil laissé ouvert sur le terrain ne doit pas
//  suffire à effacer un projet. Le serveur le vérifie ; le dialogue ne fait
//  que le transmettre.
//
//  Le dialogue reste ouvert pendant l'appel : un mot de passe faux s'affiche
//  sous le champ, qui se vide, et l'on peut recommencer. Il se referme sur la
//  réussite, que la fenêtre annonce.
//
//  Usage :
//
//      DialogueSuppressionProjet {
//        id: dialogueSuppression
//        zoneParente: fenetre.zoneUtile
//        onConfirme: function (motDePasse) { service.supprimer(id, motDePasse) }
//      }
//
//      dialogueSuppression.demander(projet);
//      dialogueSuppression.echouer(message);   // refus du serveur
//      dialogueSuppression.terminer();         // réussite
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

  // Le projet à supprimer, tel que le serveur l'a rendu.
  property var projet: null

  property bool enCours: false
  property string erreur: ""

  signal confirme(string motDePasse)

  function demander(projetDemande) {
    projet = projetDemande;
    erreur = "";
    enCours = false;
    champMotDePasse.text = "";
    open();
    champMotDePasse.forceActiveFocus();
  }

  function echouer(message) {
    enCours = false;
    erreur = message;
    champMotDePasse.text = "";
    champMotDePasse.forceActiveFocus();
  }

  function terminer() {
    enCours = false;
    close();
  }

  // Le mot de passe ne survit pas à la fenêtre.
  onClosed: champMotDePasse.text = ""

  parent: zoneParente
  width: Math.min(parent ? parent.width - 40 : 340, 460)
  x: parent ? (parent.width - width) / 2 : 0
  y: parent ? Math.max(20, (parent.height - height) / 2) : 0

  modal: true
  focus: true
  padding: 0
  // Pas de fermeture d'un geste à côté : la fenêtre ne se quitte que par un
  // bouton, et jamais pendant l'appel.
  closePolicy: enCours ? Popup.NoAutoClose : Popup.CloseOnEscape

  background: Rectangle {
    color: Theme.mainBackgroundColor
    radius: 14
    border.width: 1
    border.color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.6)
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
        source: Theme.getThemeVectorIcon("ic_delete_forever_white_24dp")
        color: Theme.errorColor
        sourceSize: Qt.size(48, 48)
      }

      Label {
        Layout.fillWidth: true
        text: dialogue.projet ? qsTr("Supprimer le projet %1 ?").arg(dialogue.projet["pro_no"]) : qsTr("Supprimer le projet ?")
        font: Theme.strongFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: {
        if (!dialogue.projet)
          return "";
        const nombreTypes = dialogue.projet["types_ue"] ? dialogue.projet["types_ue"].length : 0;
        return qsTr("Le projet « %1 » et ses %n type(s) d'UE seront supprimés définitivement de la base IFA. Cette action est irréversible.", "", nombreTypes).arg(dialogue.projet["pro_nom"]);
      }
      font: Theme.tipFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      text: qsTr("Pour confirmer, saisissez votre mot de passe QFieldCloud.")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    TextField {
      id: champMotDePasse

      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      enabled: !dialogue.enCours
      echoMode: TextInput.Password
      passwordCharacter: "•"
      placeholderText: qsTr("Mot de passe")
      inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

      onTextEdited: dialogue.erreur = ""
      onAccepted: dialogue.confirmer()
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      visible: dialogue.erreur !== ""
      text: dialogue.erreur
      font: Theme.tinyFont
      color: Theme.errorColor
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.bottomMargin: 14
      Layout.leftMargin: 12
      Layout.rightMargin: 12
      spacing: 8

      BusyIndicator {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        visible: dialogue.enCours
        running: dialogue.enCours
      }

      Item {
        Layout.fillWidth: true
      }

      QfButton {
        text: qsTr("Annuler")
        enabled: !dialogue.enCours
        bgcolor: "transparent"
        color: Theme.secondaryTextColor
        onClicked: dialogue.close()
      }

      QfButton {
        text: dialogue.enCours ? qsTr("Suppression…") : qsTr("Supprimer définitivement")
        enabled: champMotDePasse.text !== "" && !dialogue.enCours
        bgcolor: Theme.errorColor
        color: "white"
        onClicked: dialogue.confirmer()
      }
    }
  }

  function confirmer() {
    if (champMotDePasse.text === "" || enCours)
      return;

    const motDePasse = champMotDePasse.text;
    champMotDePasse.text = "";
    erreur = "";
    enCours = true;
    confirme(motDePasse);
  }
}
