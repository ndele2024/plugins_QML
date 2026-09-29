// =============================================================================
//  DialogueAttente — fenêtre d'attente centrée, du clic à l'ouverture du projet
// =============================================================================
//  Deux usages, deux instances dans `main.qml` :
//
//    * l'ouverture d'un projet préparé par le serveur — verrouillage ou
//      création de l'unité, packaging, récupération, téléchargement,
//      ouverture ;
//    * l'attente du rapport de validation après un push.
//
//  Plusieurs dizaines de secondes, parfois des minutes, pendant lesquelles un
//  toast unique ou un bandeau dans une fenêtre qui se referme laissaient croire
//  que plus rien ne se passait.
//
//  ---------------------------------------------------------------------------
//  POURQUOI DANS main.qml
//  ---------------------------------------------------------------------------
//  « Créer une UE » se referme dès que le projet est packagé, et le passeur
//  remplace ensuite le projet courant. Un dialogue posé dans une fenêtre
//  disparaîtrait en cours de route. Une seule instance, donc, dans `main.qml`,
//  rattachée à la zone utile de QField — résolue à l'ouverture, jamais à la
//  construction : la fenêtre principale n'existe pas encore quand le plugin
//  d'application se charge.
//
//  ---------------------------------------------------------------------------
//  AUCUN BOUTON
//  ---------------------------------------------------------------------------
//  Il ne se ferme que par `terminer()`. Chaque étape suivie a sa borne de
//  temps (sondage du packaging, ajout et téléchargement dans le passeur) : la
//  fenêtre ne peut pas rester bloquée, et un geste de trop ne la fait pas
//  disparaître au milieu d'un changement de projet.
//
//  ---------------------------------------------------------------------------
//  USAGE
//  ---------------------------------------------------------------------------
//      attente.suivre(qsTr("Création de l'unité 02-12777-IPE"), message);
//      attente.suivre("", message);    // même titre, nouveau message
//      attente.terminer();
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
  property string titre: ""
  property string message: ""
  property color accent: Theme.cloudColor

  // La phrase du bas, propre à chaque usage : une ouverture de projet prend
  // des minutes, une validation une minute au plus.
  property string consigne: qsTr("Patientez — cela peut prendre quelques minutes. Ne fermez pas QField.")

  // Ouvre la fenêtre si besoin et affiche l'étape en cours. Un titre vide
  // conserve le précédent : le passeur ne connaît que ses propres étapes, pas
  // ce qui a été demandé au départ.
  function suivre(nouveauTitre, nouveauMessage) {
    if (nouveauTitre)
      titre = "" + nouveauTitre;
    message = "" + (nouveauMessage ? nouveauMessage : "");

    // `iface.mainWindow()` n'est pas une propriété : une liaison ne se
    // réévaluerait jamais. La zone est donc résolue ici, au besoin.
    if (!zoneParente && iface.mainWindow())
      zoneParente = iface.mainWindow().contentItem;

    if (!opened)
      open();
  }

  function terminer() {
    close();
    titre = "";
    message = "";
  }

  // ---------------------------------------------------------------------------
  //  Présentation
  // ---------------------------------------------------------------------------
  // Sans elle, le parent serait l'Item du plugin, hors de la fenêtre de QField.
  property Item zoneParente: iface.mainWindow() ? iface.mainWindow().contentItem : null

  parent: zoneParente
  width: Math.min(parent ? parent.width - 40 : 340, 420)
  x: parent ? (parent.width - width) / 2 : 0
  y: parent ? (parent.height - height) / 2 : 0

  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.NoAutoClose

  background: Rectangle {
    color: Theme.mainBackgroundColor
    radius: 14
    border.width: 1
    border.color: Theme.controlBorderColor
  }

  contentItem: ColumnLayout {
    spacing: 14

    // ---- Titre -----------------------------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.topMargin: 20
      Layout.leftMargin: 20
      Layout.rightMargin: 20

      visible: dialogue.titre !== ""
      text: dialogue.titre
      font: Theme.strongFont
      color: Theme.mainTextColor
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    // ---- Animation -------------------------------------------------------------
    BusyIndicator {
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: dialogue.titre !== "" ? 0 : 20
      Layout.preferredWidth: 48
      Layout.preferredHeight: 48
      running: dialogue.opened
    }

    // ---- Étape en cours ----------------------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 20
      Layout.rightMargin: 20

      text: dialogue.message
      font: Theme.defaultFont
      color: dialogue.accent
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }

    // ---- Consigne ------------------------------------------------------------------
    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 20
      Layout.rightMargin: 20
      Layout.bottomMargin: 20

      text: dialogue.consigne
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
    }
  }
}
