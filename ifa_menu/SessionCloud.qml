// =============================================================================
//  SessionCloud — appels authentifiés aux points d'accès QFieldCloud
// =============================================================================
//  Une seule instance, créée dans main.qml et injectée dans les fenêtres qui
//  interrogent le serveur (comme `referentiels`).
//
//  ---------------------------------------------------------------------------
//  POURQUOI CE FICHIER EXISTE
//  ---------------------------------------------------------------------------
//  QField sait parler à QFieldCloud, mais ne prête pas son jeton : `token()`,
//  `get()` et `post()` de QFieldCloudConnection sont de simples fonctions C++,
//  ni Q_PROPERTY ni Q_INVOKABLE, donc invisibles depuis QML. Le plugin obtient
//  donc son propre jeton en s'authentifiant sur l'API avec les identifiants de
//  l'utilisateur déjà connecté — même méthode que `rapport_ife_plugin`.
//
//  Rien n'est codé en dur : l'URL du serveur et le nom d'utilisateur viennent
//  de l'objet QFieldCloudConnection de QField. Le même plugin fonctionne donc
//  sur l'instance locale, sur le VPS ou sur une adresse de réseau local.
//
//  ---------------------------------------------------------------------------
//  LE JETON PEUT ÊTRE RÉVOQUÉ SOUS NOS PIEDS
//  ---------------------------------------------------------------------------
//  Côté serveur, `AuthToken.single_token_clients` fait expirer les jetons
//  antérieurs du même utilisateur **et du même type de client**. Or les
//  requêtes QML partent avec le « User-Agent » par défaut de Qt
//  (« Mozilla/5.0 ») : le serveur les classe en `unknown`. Deux plugins IFA
//  sur le même appareil se disputeraient donc le jeton, chacun invalidant
//  celui de l'autre.
//
//  D'où la reprise sur 401 : le jeton est jeté, une nouvelle authentification
//  est demandée, et la requête est rejouée une fois. L'utilisateur ne voit
//  rien.
//
//  ⚠️ Le « User-Agent » ne peut PAS être choisi. Qt refuse cet en-tête dans
//  XMLHttpRequest (liste noire de QQmlXMLHttpRequest) et `setRequestHeader`
//  l'ignore silencieusement. Sans conséquence ici : le jeton de QField
//  lui-même est de type `qfield`, qu'un jeton `unknown` ne touche jamais.
//
//  ---------------------------------------------------------------------------
//  UTILISATION
//  ---------------------------------------------------------------------------
//    session.appeler("POST", "/api/v1/ifa/unites/recherche/", filtre,
//                    function (donnees) { … },
//                    function (message) { … });
//
//  L'appel est mis en attente si aucun jeton n'est disponible : le mot de passe
//  est demandé, puis la file est vidée. `onEchec` reçoit un message déjà
//  rédigé pour l'affichage.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import Theme

Item {
  id: session

  // ---------------------------------------------------------------------------
  //  Connexion QFieldCloud de QField
  // ---------------------------------------------------------------------------
  //  L'objet n'est pas exposé par `iface` : on l'atteint par son objectName.
  //  Ce nom ne fait pas partie de l'API publique des plugins — d'où les
  //  variantes essayées et les accès défensifs.
  property var connexionCloud: null

  readonly property string urlServeur: {
    if (!connexionCloud)
      return "";
    let url = proprieteCloud("url");
    if (url === "")
      url = proprieteCloud("defaultUrl");
    // Une barre finale doublerait le séparateur des chemins d'API.
    while (url.length > 0 && url.charAt(url.length - 1) === '/')
      url = url.substring(0, url.length - 1);
    return url;
  }

  readonly property string utilisateur: proprieteCloud("username")

  // ---------------------------------------------------------------------------
  //  État de la session
  // ---------------------------------------------------------------------------
  property string jeton: ""
  property bool authentificationEnCours: false

  // Levé quand l'utilisateur a refusé ou annulé la saisie du mot de passe :
  // empêche la boîte de dialogue de se rouvrir à chaque tentative.
  property bool authentificationAbandonnee: false

  readonly property bool disponible: urlServeur !== "" && utilisateur !== ""

  // Vrai si un appel peut partir **sans rien demander à l'utilisateur** : le
  // jeton est là, ou QField détient le mot de passe. Les appels déclenchés par
  // un geste (un bouton, une validation de formulaire) n'ont pas à s'en
  // soucier — la demande de mot de passe est alors attendue. Ceux qui partent
  // d'eux-mêmes, si : réclamer un mot de passe au démarrage de QField, pour un
  // rapport que personne n'a demandé, serait déplacé.
  readonly property bool jetonDisponible: jeton !== "" || proprieteCloud("password") !== ""

  // Appels reçus avant d'avoir un jeton. Vidée dès qu'il arrive.
  property var fileAttente: []

  // Délai maximal d'une requête. Une liaison de terrain peut être lente, mais
  // au-delà l'utilisateur mérite un message plutôt qu'un sablier éternel.
  property int delaiMaxMs: 30000

  Component.onCompleted: connexionCloud = resoudreConnexion()

  // ===========================================================================
  //  API publique
  // ===========================================================================
  //  `corps`     objet sérialisé en JSON ; `null` pour un GET.
  //  `onSucces`  reçoit la réponse déjà décodée.
  //  `onEchec`   reçoit un texte affichable tel quel, puis le code HTTP —
  //              `0` quand la requête n'a pas abouti (réseau, délai dépassé).
  //              Le second argument ne sert qu'à qui doit distinguer un cas de
  //              figure d'une panne ; les autres l'ignorent.
  function appeler(methode, chemin, corps, onSucces, onEchec) {
    if (!connexionCloud)
      connexionCloud = resoudreConnexion();

    if (!disponible) {
      onEchec(qsTr("Aucune connexion QFieldCloud active. Se connecter au serveur depuis QField, puis réessayer."), 0);
      return;
    }

    const requete = {
      "methode": methode,
      "chemin": chemin,
      "corps": corps,
      "onSucces": onSucces,
      "onEchec": onEchec,
      // Une requête n'est rejouée qu'une fois : sans ce garde-fou, un jeton
      // systématiquement refusé enfermerait le plugin dans une boucle.
      "rejouee": false
    };

    if (jeton === "") {
      empiler(requete);
      assurerJeton();
      return;
    }

    envoyer(requete);
  }

  // Referme la session : le prochain appel redemandera un jeton.
  function oublierJeton() {
    jeton = "";
  }

  // ===========================================================================
  //  Résolution de la connexion QField
  // ===========================================================================
  function resoudreConnexion() {
    const noms = ["cloudConnection", "qfieldCloudConnection", "QFieldCloudConnection"];

    for (let i = 0; i < noms.length; ++i) {
      try {
        const objet = iface.findItemByObjectName(noms[i]);
        if (objet)
          return objet;
      } catch (e) {
        // Nom inconnu de cette version de QField : on essaie le suivant.
      }
    }

    iface.logMessage("[IFA] connexion QFieldCloud introuvable");
    return null;
  }

  // Lecture défensive : selon la version de QField, une propriété donnée peut
  // ne pas être exposée à QML — y accéder renvoie alors `undefined`.
  function proprieteCloud(nom) {
    if (!connexionCloud)
      return "";

    let valeur;
    try {
      valeur = connexionCloud[nom];
    } catch (e) {
      return "";
    }

    if (valeur === undefined || valeur === null)
      return "";

    const texte = "" + valeur;
    return (texte === "undefined" || texte === "null") ? "" : texte;
  }

  // ===========================================================================
  //  File d'attente
  // ===========================================================================
  function empiler(requete) {
    const file = fileAttente.slice();
    file.push(requete);
    fileAttente = file;
  }

  function viderFile() {
    const file = fileAttente;
    fileAttente = [];
    for (let i = 0; i < file.length; ++i) {
      envoyer(file[i]);
    }
  }

  function abandonnerFile(message) {
    const file = fileAttente;
    fileAttente = [];
    for (let i = 0; i < file.length; ++i) {
      file[i].onEchec(message, 0);
    }
  }

  // ===========================================================================
  //  Envoi d'une requête
  // ===========================================================================
  function envoyer(requete) {
    const xhr = new XMLHttpRequest();
    const minuterie = composantMinuterie.createObject(session, {
      "interval": delaiMaxMs
    });

    let termine = false;

    minuterie.declenche.connect(function () {
      if (termine)
        return;
      termine = true;
      minuterie.destroy();
      xhr.abort();
      requete.onEchec(qsTr("Le serveur n'a pas répondu dans le délai imparti."), 0);
    });

    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE || termine)
        return;
      termine = true;
      minuterie.stop();
      minuterie.destroy();
      session.recevoir(xhr, requete);
    };

    try {
      xhr.open(requete.methode, urlServeur + requete.chemin);
      xhr.setRequestHeader("Content-Type", "application/json");
      xhr.setRequestHeader("Accept", "application/json");
      xhr.setRequestHeader("Authorization", "Token " + jeton);
      minuterie.start();
      xhr.send(requete.corps === null || requete.corps === undefined ? "" : JSON.stringify(requete.corps));
    } catch (e) {
      termine = true;
      minuterie.stop();
      minuterie.destroy();
      requete.onEchec(qsTr("Impossible de joindre le serveur : %1").arg(e), 0);
    }
  }

  function recevoir(xhr, requete) {
    // Jeton révoqué (autre plugin, expiration) : on en redemande un et on
    // rejoue la requête, une seule fois.
    if (xhr.status === 401 && !requete.rejouee) {
      requete.rejouee = true;
      jeton = "";
      authentificationAbandonnee = false;
      empiler(requete);
      assurerJeton();
      return;
    }

    if (xhr.status === 0) {
      requete.onEchec(qsTr("Serveur injoignable. Vérifier la connexion réseau."), 0);
      return;
    }

    let donnees = null;
    if (xhr.responseText !== "") {
      try {
        donnees = JSON.parse(xhr.responseText);
      } catch (e) {
        donnees = null;
      }
    }

    if (xhr.status >= 200 && xhr.status < 300) {
      requete.onSucces(donnees);
      return;
    }

    // QFieldCloud rend ses erreurs sous la forme { code, message }.
    const message = donnees && donnees.message ? donnees.message : qsTr("Le serveur a répondu par une erreur (HTTP %1).").arg(xhr.status);

    // Le statut est passé en second argument, pour les appelants qui ont
    // besoin de distinguer un cas de figure d'une panne — un rapport de
    // validation pas encore produit répond 404, et ce n'est pas une erreur à
    // afficher. Les autres l'ignorent : une fonction JavaScript ne s'offusque
    // pas d'un argument de plus.
    requete.onEchec(message, xhr.status);
  }

  // ===========================================================================
  //  Authentification
  // ===========================================================================
  function assurerJeton() {
    if (jeton !== "") {
      viderFile();
      return;
    }

    if (authentificationEnCours)
      return;

    // QField ne conserve normalement que son jeton ; le mot de passe n'est là
    // que si l'utilisateur a demandé à le mémoriser.
    const motDePasse = proprieteCloud("password");
    if (motDePasse !== "") {
      connecter(motDePasse);
      return;
    }

    if (authentificationAbandonnee) {
      abandonnerFile(qsTr("Authentification nécessaire pour interroger le serveur."));
      return;
    }

    if (!dialogueMotDePasse.visible) {
      if (!dialogueMotDePasse.resoudreZoneParente()) {
        // Sans zone où s'afficher, `open()` ne ferait rien : les appels
        // resteraient en file, sans que rien ne le dise.
        iface.logMessage("[IFA] fenetre principale introuvable : mot de passe non demande");
        abandonnerFile(qsTr("Authentification impossible pour le moment. Réessayer."));
        return;
      }

      dialogueMotDePasse.messageErreur = "";
      dialogueMotDePasse.open();
    }
  }

  //  POST /api/v1/auth/login/ → { token, expires_at }
  //  Le mot de passe ne vit que le temps de cet appel : il n'est ni conservé
  //  ni journalisé.
  function connecter(motDePasse) {
    authentificationEnCours = true;

    const xhr = new XMLHttpRequest();

    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE)
        session.reponseConnexion(xhr);
    };

    // L'API accepte « username » OU « email », et privilégie « email » quand
    // il est renseigné. On ne remplit « email » que si l'identifiant en a la
    // forme : un champ EmailField invalide ferait échouer la requête.
    const charge = {
      "username": utilisateur,
      "password": motDePasse
    };
    if (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(utilisateur))
      charge.email = utilisateur;

    try {
      xhr.open("POST", urlServeur + "/api/v1/auth/login/");
      xhr.setRequestHeader("Content-Type", "application/json");
      xhr.send(JSON.stringify(charge));
    } catch (e) {
      authentificationEnCours = false;
      abandonnerFile(qsTr("Impossible de joindre le serveur : %1").arg(e));
    }
  }

  function reponseConnexion(xhr) {
    authentificationEnCours = false;

    if (xhr.status === 200) {
      let donnees = null;
      try {
        donnees = JSON.parse(xhr.responseText);
      } catch (e) {
        donnees = null;
      }

      if (donnees && donnees.token) {
        jeton = donnees.token;
        authentificationAbandonnee = false;
        dialogueMotDePasse.messageErreur = "";
        dialogueMotDePasse.close();
        viderFile();
        return;
      }

      abandonnerFile(qsTr("Le serveur n'a pas renvoyé de jeton d'authentification."));
      return;
    }

    if (xhr.status === 400 || xhr.status === 401) {
      dialogueMotDePasse.messageErreur = qsTr("Mot de passe refusé pour « %1 ».").arg(utilisateur);
      if (!dialogueMotDePasse.visible)
        dialogueMotDePasse.open();
      return;
    }

    authentificationAbandonnee = true;
    abandonnerFile(xhr.status === 0 ? qsTr("Serveur injoignable. Vérifier la connexion réseau.") : qsTr("Échec de l'authentification (HTTP %1).").arg(xhr.status));
  }

  // ===========================================================================
  //  Composants
  // ===========================================================================
  //  Une minuterie par requête, créée à la volée : plusieurs recherches
  //  peuvent être en vol en même temps, un `Timer` unique les mélangerait.
  //  Le signal est renommé pour ne pas masquer `Timer.triggered`, que
  //  `connect()` ne saurait plus distinguer du gestionnaire déclaratif.
  Component {
    id: composantMinuterie

    Timer {
      signal declenche

      repeat: false
      onTriggered: declenche()
    }
  }

  // ---- Demande du mot de passe ------------------------------------------------
  Popup {
    id: dialogueMotDePasse

    property string messageErreur: ""

    // Même piège que pour `IfaPopup` et `DialogueDeverrouillage` : cette
    // session est construite au chargement du plugin, avant que la fenêtre
    // principale n'existe. `iface.mainWindow()` n'étant pas une propriété, une
    // liaison évaluée à ce moment-là resterait nulle pour toujours, et le
    // dialogue ne s'afficherait jamais — sans erreur. D'où la zone gardée dans
    // une propriété, et résolue de nouveau avant chaque ouverture.
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

    parent: zoneParente
    width: Math.min(parent ? parent.width - 40 : 320, 420)
    x: parent ? (parent.width - width) / 2 : 0
    y: parent ? (parent.height - height) / 2 : 0

    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape

    onOpened: champMotDePasse.forceActiveFocus()

    onClosed: {
      champMotDePasse.text = "";
      // Fermeture sans jeton : c'est un renoncement de l'utilisateur. On ne le
      // relance pas à la tentative suivante.
      if (session.jeton === "") {
        session.authentificationAbandonnee = true;
        session.abandonnerFile(qsTr("Authentification annulée."));
      }
    }

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
        text: qsTr("Connexion au serveur IFA")
        font: Theme.strongFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }

      Label {
        Layout.fillWidth: true
        Layout.leftMargin: 18
        Layout.rightMargin: 18
        text: qsTr("Mot de passe de « %1 » sur %2.").arg(session.utilisateur).arg(session.urlServeur)
        font: Theme.tipFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }

      TextField {
        id: champMotDePasse

        Layout.fillWidth: true
        Layout.leftMargin: 18
        Layout.rightMargin: 18

        echoMode: TextInput.Password
        placeholderText: qsTr("Mot de passe")
        enabled: !session.authentificationEnCours

        onAccepted: dialogueMotDePasse.valider()
      }

      Label {
        Layout.fillWidth: true
        Layout.leftMargin: 18
        Layout.rightMargin: 18
        visible: dialogueMotDePasse.messageErreur !== ""
        text: dialogueMotDePasse.messageErreur
        font: Theme.tipFont
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
          Layout.preferredWidth: 22
          Layout.preferredHeight: 22
          Layout.leftMargin: 6
          running: session.authentificationEnCours
          visible: session.authentificationEnCours
        }

        Item {
          Layout.fillWidth: true
        }

        QfButton {
          text: qsTr("Annuler")
          bgcolor: "transparent"
          color: Theme.secondaryTextColor
          onClicked: dialogueMotDePasse.close()
        }

        QfButton {
          text: qsTr("Se connecter")
          enabled: champMotDePasse.text !== "" && !session.authentificationEnCours
          bgcolor: Theme.mainColor
          color: "#ffffff"
          onClicked: dialogueMotDePasse.valider()
        }
      }
    }

    function valider() {
      if (champMotDePasse.text === "" || session.authentificationEnCours)
        return;
      messageErreur = "";
      session.connecter(champMotDePasse.text);
    }
  }
}
