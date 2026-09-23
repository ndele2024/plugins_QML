// =============================================================================
//  DialogueDeverrouillage — rendre l'unité après une synchronisation
// =============================================================================
//  Posé juste après un push accepté par le serveur. Le technicien vient de
//  renvoyer sa saisie : s'il en a fini avec l'unité, elle doit redevenir
//  disponible pour les autres équipes — sinon elle reste tenue à son nom,
//  et personne d'autre ne pourra l'ouvrir tant qu'un administrateur ne sera
//  pas intervenu dans la base.
//
//  La question est posée **avant** toute requête, y compris avant la demande
//  du mot de passe : le technicien décide d'abord, la session s'occupe ensuite
//  de s'authentifier si son jeton est perdu (voir `SessionCloud`).
//
//  ---------------------------------------------------------------------------
//  POURQUOI CE DIALOGUE ATTEND LA RÉPONSE
//  ---------------------------------------------------------------------------
//  Le déverrouillage n'est qu'une requête, mais elle a trois issues à dire au
//  technicien — relâchée, déjà libre, refusée parce qu'un autre la tient. Les
//  laisser à l'appelant reviendrait à disperser en trois endroits ce qui se lit
//  ici d'un coup. Le dialogue rend donc `termine(deverrouille)` quand il n'y a
//  plus rien à attendre, et l'appelant enchaîne sans avoir à savoir ce qui
//  s'est passé.
//
//  La requête elle-même est déléguée à `ServiceVerrou`, qui est aussi ce
//  qu'appelle le bouton de déverrouillage du tableau des résultats : le point
//  d'accès n'est écrit qu'une fois.
//
//  Usage :
//
//      DialogueDeverrouillage {
//        id: dialogueDeverrouillage
//        session: sessionCloud
//        onTermine: function (deverrouille) { … }
//      }
//
//      dialogueDeverrouillage.demander("02-12777-IPE");
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
  // Session QFieldCloud, injectée : c'est elle qui porte le jeton et qui
  // demandera le mot de passe si nécessaire.
  property var session: null

  // Zone dans laquelle centrer la fenêtre. Ce dialogue n'a pas de fenêtre IFA
  // au-dessus de lui — il surgit sur la carte — d'où le repli sur le
  // `contentItem` de la fenêtre principale.
  //
  // **Non `readonly`, et résolue de nouveau avant chaque ouverture.** Ce
  // dialogue est construit au chargement du plugin, c'est-à-dire avant que la
  // fenêtre principale de QField n'existe — le même moment où le bouton de la
  // barre d'outils doit être réessayé vingt fois (voir `main.qml`).
  // `iface.mainWindow()` n'étant pas une propriété, la liaison ne se
  // réévaluerait jamais d'elle-même : la zone resterait nulle, le `parent` du
  // Popup aussi, et `open()` n'afficherait rien — sans la moindre erreur.
  property Item zoneParente: iface.mainWindow() ? iface.mainWindow().contentItem : null

  function resoudreZoneParente() {
    if (zoneParente)
      return true;

    const principale = iface.mainWindow();

    if (principale)
      zoneParente = principale.contentItem;

    return zoneParente !== null;
  }

  onAboutToShow: resoudreZoneParente()

  // Unité concernée.
  property string uniteCode: ""

  property bool enCours: false

  // Émis dans tous les cas une fois la question réglée : refus, succès, ou
  // échec. `deverrouille` dit ce qui est arrivé à l'unité.
  signal termine(bool deverrouille)

  // Le service porte la requête. Déclaré comme propriété plutôt qu'en enfant :
  // le contenu d'un `Popup` est visuel, et un objet sans représentation n'y a
  // pas sa place.
  property ServiceVerrou service: ServiceVerrou {
    session: dialogue.session

    onDeverrouille: function (verrou, change) {
      dialogue.reussi(change);
    }

    onEchec: function (message) {
      dialogue.echoue(message);
    }
  }

  function demander(code) {
    uniteCode = "" + (code ? code : "");

    if (uniteCode === "") {
      // Rien à déverrouiller : le projet ouvert ne dit pas quelle unité il
      // porte. On ne pose pas une question sans objet — mais on le dit, sans
      // quoi l'absence de dialogue ressemble à une panne.
      iface.logMessage("[IFA] pas de variable de projet « une_code_ident » : deverrouillage non propose");
      termine(false);
      return;
    }

    if (!resoudreZoneParente()) {
      // Sans zone où s'afficher, `open()` ne ferait rien du tout, en silence.
      iface.logMessage("[IFA] fenetre principale de QField introuvable : deverrouillage non propose");
      termine(false);
      return;
    }

    enCours = false;
    open();

    iface.logMessage("[IFA] deverrouillage propose pour " + uniteCode);
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
  // Ni Escape ni clic extérieur : la question mérite une réponse. La refuser
  // est un choix légitime, mais il se dit par le bouton.
  closePolicy: Popup.NoAutoClose

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

      text: qsTr("Déverrouiller l'unité %1 ?").arg(dialogue.uniteCode)
      font: Theme.strongFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    Label {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18

      text: qsTr("Vos modifications ont été synchronisées. Tant que l'unité reste verrouillée, les autres équipes ne peuvent pas l'ouvrir.")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: 18
      Layout.rightMargin: 18
      spacing: 10

      visible: dialogue.enCours

      // La requête part vers le serveur : une roue qui tourne dit que quelque
      // chose se passe là où un texte seul laisse croire à une fenêtre figée.
      BusyIndicator {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        running: dialogue.enCours
      }

      Label {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter

        text: qsTr("Déverrouillage en cours…")
        font: Theme.tinyFont
        color: Theme.mainColor
        wrapMode: Text.WordWrap
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
        text: qsTr("Garder verrouillée")
        enabled: !dialogue.enCours
        bgcolor: "transparent"
        color: Theme.secondaryTextColor
        onClicked: dialogue.refuser()
      }

      QfButton {
        text: qsTr("Déverrouiller")
        enabled: !dialogue.enCours
        onClicked: dialogue.confirmer()
      }
    }
  }

  // ===========================================================================
  //  Actions
  // ===========================================================================
  function refuser() {
    close();
    termine(false);
  }

  function confirmer() {
    if (!session) {
      close();
      avertir(qsTr("Le déverrouillage n'est pas possible : aucune session QFieldCloud."), "warning");
      termine(false);
      return;
    }

    enCours = true;
    service.deverrouiller(uniteCode);
  }

  // Le serveur distingue « le verrou est tombé » de « il n'y en avait pas ».
  // Le second cas n'est pas un incident — l'unité est disponible, c'est ce qui
  // était demandé — mais le dire évite de laisser croire à une action qui n'a
  // pas eu lieu.
  function reussi(relachee) {
    enCours = false;
    close();

    avertir(relachee ? qsTr("Unité %1 déverrouillée.").arg(uniteCode) : qsTr("L'unité %1 n'était pas verrouillée.").arg(uniteCode), "success");

    termine(relachee);
  }

  function echoue(message) {
    enCours = false;
    close();

    // L'unité reste tenue. Ce n'est pas bloquant pour la suite — le rapport de
    // validation s'obtient indépendamment — mais le technicien doit le savoir :
    // il croirait l'avoir rendue.
    avertir(qsTr("Déverrouillage impossible : %1").arg(message), "error");

    termine(false);
  }

  // `IfaPopup.avertir()` n'est pas visible d'ici : ce dialogue est autonome et
  // surgit sans fenêtre IFA au-dessus de lui.
  function avertir(message, type) {
    const principale = iface.mainWindow();

    if (principale && typeof principale.displayToast === "function")
      principale.displayToast(message, type ? type : "info");
    else
      iface.logMessage("[IFA] " + message);
  }
}
