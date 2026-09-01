import QtQuick 2.14
import QtQuick.Controls 2.14
import QtQuick.Layouts 1.14
import org.qfield 1.0
import Theme 1.0

Item {
    id: root

    // ── Connexion cloud ───────────────────────────────────────────────
    // Aucune URL ni token en dur : tout vient de l'objet QFieldCloudConnection
    // de QField. Il n'est PAS exposé par iface (AppInterface n'a aucun membre
    // cloud) mais reste atteignable par son objectName.
    //
    // Le token, lui, n'est pas lisible depuis QML (token()/get()/post() sont de
    // simples fonctions C++, ni Q_PROPERTY ni Q_INVOKABLE). On en obtient donc
    // un à nous en s'authentifiant sur l'API avec les identifiants de
    // l'utilisateur déjà connecté.
    property var cloudConnection: null

    function resolveCloudConnection() {
        var names = ["cloudConnection", "qfieldCloudConnection", "QFieldCloudConnection"]
        for (var i = 0; i < names.length; i++) {
            try {
                var o = iface.findItemByObjectName(names[i])
                if (o) return o
            } catch (e) { /* nom inconnu : on essaie le suivant */ }
        }
        return null
    }

    // Lecture défensive : selon la version de QField, une propriété donnée peut
    // ne pas être exposée à QML — y accéder renvoie alors undefined.
    function cloudProp(name) {
        if (!cloudConnection) return ""
        var v
        try { v = cloudConnection[name] } catch (e) { return "" }
        if (v === undefined || v === null) return ""
        var s = "" + v
        return (s === "undefined" || s === "null") ? "" : s
    }

    readonly property string serverUrl: {
        if (!cloudConnection) return ""
        var u = cloudProp("url")
        if (u === "") u = cloudProp("defaultUrl")
        // Une barre finale doublerait le séparateur des chemins d'API.
        while (u.length > 0 && u.charAt(u.length - 1) === '/')
            u = u.substring(0, u.length - 1)
        return u
    }

    readonly property string cloudUsername: cloudConnection ? cloudProp("username") : ""

    // ── Session obtenue par authentification ──────────────────────────
    property string authToken:      ""
    property string tokenExpiresAt: ""
    property bool   loginInFlight:  false
    // Levé quand l'identification a été refusée ou annulée : empêche la boîte
    // de dialogue de se rouvrir toute seule à chaque sondage (3 s).
    property bool   authFailed:     false

    // Chemin du projet courant. Dans un plugin QField, le projet est exposé
    // via la propriété globale « qgisProject » ; homePath en est une propriété.
    readonly property string projectHome: {
        if (typeof qgisProject !== "undefined" && qgisProject)
            return "" + qgisProject.homePath
        return ""
    }

    // projectId (UUID) extrait du dossier cloud QField : .../cloud_projects/{org}/{uuid}/
    readonly property string projectId: {
        var home = projectHome.replace(/\\/g, '/')
        if (home === "") return ""
        var parts = home.split('/')
        var uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
        for (var i = parts.length - 1; i >= 0; i--) {
            if (uuidRe.test(parts[i])) return parts[i]
        }
        return ""
    }

    // ── État ─────────────────────────────────────────────────────────
    property var    report:               null
    property bool   loaded:               false
    property bool   reportStale:          false
    property bool   waitingForSync:       false
    property string lastLoadedPackagedAt: ""
    property string lastSeenPackagedAt:   ""

    // Version amortie de waitingForSync (voir syncDelay) : c'est elle qui
    // pilote l'affichage. On s'appuie sur waitingForSync plutôt que sur un
    // compteur de requêtes en vol, car ce dernier retomberait à zéro entre la
    // réponse du paquet et l'envoi de la requête rapport — un creux qui
    // relancerait l'amortissement au milieu d'un cycle pourtant continu.
    property bool syncVisible: false

    // Garde de non-chevauchement du sondage deltafile (400 ms, asynchrone).
    property bool deltaCheckInFlight: false

    onWaitingForSyncChanged: {
        if (waitingForSync) { syncDelay.restart(); syncWatchdog.restart() }
        else                { syncDelay.stop(); syncVisible = false; syncWatchdog.stop() }
    }

    // ── Diagnostic (visible via le panneau) ──────────────────────────
    property string diagPackageStatus: "—"
    property string diagReportStatus:  "—"
    property string diagLoginStatus:   "—"
    property string diagPackagedAt:    "—"
    property string diagDeltaCount:    "—"
    property string diagMessage:       "Initialisation…"

    readonly property bool reportReady: loaded && !reportStale

    // Les deux formes d'attente, réunies parce que le technicien les vit de la
    // même façon : sa question « mon rapport est-il à jour ? » n'a pas encore
    // de réponse — que ce soit parce qu'on interroge le serveur, ou parce que
    // des deltas poussés attendent d'être validés.
    readonly property bool waiting: syncVisible || reportStale

    readonly property color buttonColor: {
        if (!reportReady)              return "#757575"
        if (report && report.is_valid) return "#2e7d32"
        return "#c62828"
    }

    readonly property string deltafilePath: {
        if (projectHome === "") return ""
        var p = ("" + projectHome).replace(/\\/g, '/')
        // Une URL file:// veut un chemin ABSOLU commençant par « / ». Sous
        // Android le homePath commence déjà par « / » et « file:// » + chemin
        // donne bien trois barres ; sous Windows il commence par « C:/ », et
        // sans cet ajout on obtient file://C:/… où « C: » est lu comme nom
        // d'hôte — la lecture échoue silencieusement à chaque sondage.
        if (p.charAt(0) !== '/') p = '/' + p
        return "file://" + encodeURI(p) + "/deltafile.json"
    }

    // ── Initialisation ────────────────────────────────────────────────
    Component.onCompleted: {
        iface.addItemToPluginsToolbar(toolbarButton)
        // Après construction de l'arbre applicatif : findItemByObjectName()
        // ne trouverait rien si on l'appelait plus tôt.
        cloudConnection = resolveCloudConnection()
        if (!cloudConnection)
            diagMessage = "Connexion QFieldCloud introuvable dans QField"
        checkDeltafile()
        checkPackage()   // déclenche l'authentification si nécessaire
        pollTimer.start()
        deltaTimer.start()
    }

    // ── Sondage serveur : 3 s ─────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: 3000
        repeat: true
        onTriggered: root.checkPackage()
    }

    // ── Sondage deltafile local : 400 ms ──────────────────────────────
    // Séparé du sondage serveur, et bien plus rapide : c'est ce fichier qui
    // signale le geste du technicien (saisie puis push), et attendre le
    // prochain tour de 3 s ferait apparaître le sablier longtemps après le
    // clic. Lecture d'un fichier local de quelques centaines d'octets.
    Timer {
        id: deltaTimer
        interval: 400
        repeat: true
        onTriggered: root.checkDeltafile()
    }

    // Un aller-retour réseau nominal dure quelques dizaines de millisecondes :
    // afficher le sablier sans délai le ferait clignoter à chaque sondage, ce
    // qui se lit comme un défaut d'affichage plutôt que comme une attente.
    Timer {
        id: syncDelay
        interval: 300
        onTriggered: root.syncVisible = true
    }

    // Garde-fou. Le cycle paquet → rapport est protégé contre le
    // chevauchement par waitingForSync ; une connexion qui ne répond jamais
    // laisserait donc ce drapeau levé et figerait le plugin sur le sablier,
    // sans plus jamais sonder. Au-delà du délai, on repart de zéro.
    Timer {
        id: syncWatchdog
        interval: 20000
        onTriggered: {
            root.waitingForSync = false
            root.diagMessage    = "Délai dépassé — le serveur n'a pas répondu"
        }
    }

    // ── Authentification ──────────────────────────────────────────────

    // Garantit qu'on dispose d'un token, en demandant le mot de passe si
    // QField ne le détient pas (cas habituel : il ne conserve que son token).
    function ensureToken() {
        if (authToken !== "" || loginInFlight) return
        if (!cloudConnection) { diagMessage = "Connexion QFieldCloud introuvable dans QField" ; return }
        if (serverUrl === "") { diagMessage = "URL du serveur QFieldCloud inconnue" ; return }
        if (cloudUsername === "") { diagMessage = "Aucun utilisateur QFieldCloud connecté" ; return }

        var pwd = cloudProp("password")
        if (pwd !== "") { doLogin(pwd) ; return }

        // Ni token ni mot de passe : il faut le demander. On ne rouvre pas la
        // boîte tant que l'utilisateur ne l'a pas redemandée (bouton du
        // panneau) — sinon elle reviendrait toutes les 3 secondes.
        if (authFailed || passwordDialog.visible) return
        passwordDialog.errorText = ""
        passwordDialog.open()
    }

    // POST /api/v1/auth/login/ → { token, expires_at }
    // Le mot de passe n'est ni conservé ni journalisé : il ne vit que le temps
    // de cet appel, l'échange se faisant sur la même connexion que QField.
    function doLogin(password) {
        loginInFlight = true
        diagMessage   = "Authentification en cours…"

        var xhr = new XMLHttpRequest()
        var settled = false

        function settle() {
            if (settled) return
            settled = true
            root.onLoginReply(xhr)
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) settle()
        }

        // L'API accepte « username » OU « email », et privilégie « email »
        // quand il est renseigné — certains serveurs n'autorisent d'ailleurs
        // que celui-ci. On ne remplit « email » que si l'identifiant en a la
        // forme : un champ EmailField non valide ferait échouer la requête.
        var payload = { username: cloudUsername, password: password }
        if (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(cloudUsername))
            payload.email = cloudUsername

        try {
            xhr.open("POST", serverUrl + "/api/v1/auth/login/")
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.send(JSON.stringify(payload))
        } catch (e) {
            root.diagMessage = "Erreur réseau (connexion) : " + e
            settle()
        }
    }

    function onLoginReply(xhr) {
        loginInFlight  = false
        diagLoginStatus = "" + xhr.status

        if (xhr.status === 200) {
            var data
            try { data = JSON.parse(xhr.responseText) }
            catch (e) { diagMessage = "Réponse d'authentification illisible" ; return }

            if (data && data.token) {
                authToken      = data.token
                tokenExpiresAt = data.expires_at || ""
                authFailed     = false
                diagMessage    = "Authentifié : " + cloudUsername
                passwordDialog.errorText = ""
                passwordDialog.close()
                checkPackage()          // enchaîne immédiatement
                return
            }
            diagMessage = "Authentification sans token dans la réponse"
            return
        }

        if (xhr.status === 400 || xhr.status === 401) {
            authFailed  = true
            diagMessage = "Identifiants refusés"
            passwordDialog.errorText = "Mot de passe refusé pour « " + cloudUsername + " »."
            if (!passwordDialog.visible) passwordDialog.open()
            return
        }

        authFailed  = true
        diagMessage = (xhr.status === 0)
            ? "Connexion impossible au serveur (URL/SSL ?)"
            : "Échec de l'authentification (HTTP " + xhr.status + ")"
    }

    // Token refusé en cours de route (expiré, révoqué) : on le jette et on
    // relance le cycle d'authentification.
    function invalidateToken(reason) {
        authToken   = ""
        authFailed  = false      // ce n'est pas l'utilisateur qui a échoué
        diagMessage = reason
        ensureToken()
    }

    // ── Lecture du deltafile local ────────────────────────────────────

    // Lit deltafile.json local : s'il contient des deltas non encore
    // validés, le rapport affiché est « périmé » (sablier).
    // Asynchrone comme les requêtes réseau — à 400 ms d'intervalle, une
    // lecture bloquante finirait par se voir à l'usage.
    function checkDeltafile() {
        if (!deltafilePath || deltaCheckInFlight) return
        deltaCheckInFlight = true

        var xhr = new XMLHttpRequest()
        var settled = false

        function settle() {
            if (settled) return
            settled = true
            root.deltaCheckInFlight = false
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            settle()
            // Sur une URL file:// Qt laisse status à 0 même en cas de succès :
            // c'est le corps de la réponse qui fait foi, pas le code HTTP.
            root.applyDeltaCount(xhr.responseText)
        }

        try { xhr.open("GET", deltafilePath) ; xhr.send() }
        catch (e) { settle() ; diagDeltaCount = "(illisible)" }
    }

    function applyDeltaCount(text) {
        if (!text) { diagDeltaCount = "0" ; return }
        try {
            var delta = JSON.parse(text)
            var n = (delta.deltas && delta.deltas.length) ? delta.deltas.length : 0
            diagDeltaCount = "" + n
            // Levé dès la première saisie, abaissé seulement par l'arrivée d'un
            // rapport frais (voir onReportReply) : le sablier couvre donc tout
            // l'intervalle saisie → push → validation → rapport, sans trou au
            // moment où QField vide le deltafile après l'envoi.
            if (n > 0) reportStale = true
        } catch (e) { diagDeltaCount = "(illisible)" }
    }

    // ── Requêtes authentifiées ────────────────────────────────────────

    // Lance un GET authentifié et appelle onDone(xhr) à la réception.
    // Asynchrone délibérément : une requête synchrone (3e argument `false` de
    // open()) bloque le thread QML, donc figerait le sablier pendant
    // exactement l'attente qu'il est censé signaler.
    function authGet(url, onDone) {
        var xhr = new XMLHttpRequest()
        var settled = false

        function settle() {
            if (settled) return   // open()/send() peut lever après que le
            settled = true        // handler soit déjà passé par DONE
            onDone(xhr)
        }

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) settle()
        }

        try {
            xhr.open("GET", url)
            xhr.setRequestHeader("Authorization", "Token " + authToken)
            xhr.send()
        } catch (e) {
            root.diagMessage = "Erreur réseau : " + e
            settle()
        }
    }

    // Interroge le paquet le plus récent et déclenche un rechargement du
    // rapport UNIQUEMENT si les données ont changé depuis le dernier
    // chargement (comparaison du timestamp data_last_updated_at).
    function checkPackage() {
        if (waitingForSync) return
        if (!projectId) { diagMessage = "projectId introuvable (voir chemin projet)" ; return }
        if (authToken === "") { ensureToken() ; return }

        waitingForSync = true
        authGet(serverUrl + "/api/v1/packages/" + projectId + "/latest/",
                function(xhr) { root.onPackageReply(xhr) })
    }

    function onPackageReply(xhr) {
        diagPackageStatus = "" + xhr.status

        if (xhr.status === 401 || xhr.status === 403) {
            waitingForSync = false
            invalidateToken("Session expirée — reconnexion nécessaire")
            return
        }

        if (xhr.status !== 200) {
            diagMessage = (xhr.status === 400)
                ? "Projet jamais packagé sur QFieldCloud"
                : (xhr.status === 0)
                    ? "Connexion impossible (URL/SSL ? voir serveur)"
                    : "Paquet indisponible (HTTP " + xhr.status + ")"
            waitingForSync = false
            return
        }

        var meta
        try { meta = JSON.parse(xhr.responseText) }
        catch (e) { diagMessage = "Réponse paquet illisible" ; waitingForSync = false ; return }

        // data_last_updated_at avance à CHAQUE push (delta_apply), contrairement à
        // packaged_at qui ne bouge que lors d'un job « package ». Un push régénère le
        // rapport SANS repackager → packaged_at reste figé. On suit donc le timestamp
        // de dernière mise à jour des données, qui est le vrai signal de changement.
        var changeStamp = meta.data_last_updated_at || meta.packaged_at || ""
        diagPackagedAt = changeStamp || "(absent)"

        // Rien de neuf depuis le dernier traitement (200 ou 404 déjà constaté)
        if (changeStamp !== "" && changeStamp === lastSeenPackagedAt) {
            waitingForSync = false
            return
        }

        fetchReport(changeStamp)
    }

    // Télécharge rapport_ife.json depuis l'API QFieldCloud.
    function fetchReport(packagedAt) {
        authGet(serverUrl + "/api/v1/packages/" + projectId + "/latest/files/rapport_ife.json/",
                function(xhr) { root.onReportReply(xhr, packagedAt) })
    }

    // Mémorise le timestamp (pour éviter les re-téléchargements) uniquement
    // sur issue définitive (200 = rapport, 404 = pas de rapport).
    function onReportReply(xhr, packagedAt) {
        waitingForSync = false   // dernier maillon de la chaîne paquet → rapport
        diagReportStatus = "" + xhr.status

        if (xhr.status === 401 || xhr.status === 403) {
            invalidateToken("Session expirée — reconnexion nécessaire")
            return
        }

        if (xhr.status === 200 && xhr.responseText && xhr.responseText.length > 0) {
            try {
                report = JSON.parse(xhr.responseText)
            } catch (e) { diagMessage = "Rapport JSON illisible" ; return }
            loaded = true
            reportStale = false
            lastLoadedPackagedAt = packagedAt
            lastSeenPackagedAt = packagedAt
            diagMessage = report.is_valid ? "Rapport chargé : VALIDE" : "Rapport chargé : INVALIDE"
            return
        }

        if (xhr.status === 404) {
            // L'attente est terminée même sans rapport : le serveur a fini de
            // traiter le push, il n'a simplement rien produit. Laisser le
            // sablier tourner ici le ferait tourner indéfiniment.
            reportStale = false
            lastSeenPackagedAt = packagedAt   // paquet sans rapport → ne pas re-hammerer
            diagMessage = "Paquet OK mais aucun rapport (validation non exécutée)"
            return
        }

        // Erreur transitoire : on NE mémorise PAS → le prochain poll retentera
        diagMessage = "Rapport indisponible (HTTP " + xhr.status + ")"
    }

    // ── Boîte de dialogue mot de passe ────────────────────────────────
    Dialog {
        id: passwordDialog
        parent: iface.mainWindow().contentItem
        x: (parent.width  - width)  / 2
        y: (parent.height - height) / 2
        width: Math.min(parent.width * 0.9, 400)
        modal: true
        focus: true
        title: "Connexion QFieldCloud"
        standardButtons: Dialog.Ok | Dialog.Cancel

        property string errorText: ""

        background: Rectangle { color: Theme.mainBackgroundColor; radius: 10 }

        onOpened: { pwdField.text = "" ; pwdField.forceActiveFocus() }

        // Le mot de passe est effacé du champ dès qu'il est transmis : il ne
        // survit ni dans l'interface ni dans une propriété du plugin.
        onAccepted: {
            var p = pwdField.text
            pwdField.text = ""
            if (p === "") {
                passwordDialog.errorText = "Le mot de passe ne peut pas être vide."
                passwordDialog.open()
                return
            }
            root.doLogin(p)
        }

        onRejected: {
            pwdField.text = ""
            root.authFailed  = true
            root.diagMessage = "Authentification requise pour afficher le rapport"
        }

        ColumnLayout {
            width: parent.width
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: root.cloudUsername !== ""
                      ? "Saisissez le mot de passe de « " + root.cloudUsername + " » pour consulter le rapport de validation."
                      : "Aucun utilisateur QFieldCloud connecté."
                font.pixelSize: 13
                color: Theme.mainTextColor
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                text: root.serverUrl
                font.pixelSize: 11
                color: Theme.secondaryTextColor
                wrapMode: Text.WrapAnywhere
            }

            TextField {
                id: pwdField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Mot de passe"
                onAccepted: passwordDialog.accept()   // validation au clavier
            }

            Text {
                Layout.fillWidth: true
                visible: passwordDialog.errorText !== ""
                text: passwordDialog.errorText
                font.pixelSize: 12
                color: "#c62828"
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Bouton toolbar ────────────────────────────────────────────────
    // ToolButton (contrôle natif) : onClicked est capté de façon fiable
    // dans la barre d'outils des plugins, contrairement à un Rectangle+MouseArea.
    ToolButton {
        id: toolbarButton
        implicitWidth: 48
        implicitHeight: 48

        background: Rectangle {
            color: buttonColor
            radius: 6
        }

        ToolTip.visible: hovered && root.waiting
        ToolTip.text: "Veuillez patienter…"

        contentItem: Item {
            // Sablier dessiné plutôt que glyphe ⏳ : la barre d'outils tourne
            // sur Android comme sur desktop, et la présence d'une police
            // couvrant les emoji n'y est pas garantie.
            Canvas {
                id: hourglass
                visible: root.waiting
                anchors.centerIn: parent
                width: 24; height: 28

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "white"
                    ctx.fillStyle   = "white"
                    ctx.lineWidth   = 2
                    ctx.lineCap     = "round"

                    // Plateaux haut et bas
                    ctx.beginPath()
                    ctx.moveTo(3,  2); ctx.lineTo(21,  2)
                    ctx.moveTo(3, 26); ctx.lineTo(21, 26)
                    ctx.stroke()

                    // Les deux ampoules, pleines : à 24 px un simple contour
                    // se réduirait à une bouillie de traits.
                    ctx.beginPath()
                    ctx.moveTo(5,  4); ctx.lineTo(19,  4); ctx.lineTo(12, 14); ctx.closePath()
                    ctx.moveTo(5, 24); ctx.lineTo(19, 24); ctx.lineTo(12, 14); ctx.closePath()
                    ctx.fill()
                }

                // Retournement, pas rotation continue : un sablier qui tourne
                // sans fin cesse d'être lu comme un sablier.
                SequentialAnimation on rotation {
                    running: root.waiting
                    loops: Animation.Infinite
                    PauseAnimation { duration: 1000 }
                    NumberAnimation { from: 0;   to: 180; duration: 450; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 1000 }
                    NumberAnimation { from: 180; to: 360; duration: 450; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                visible: !root.waiting
                anchors.centerIn: parent
                text: "IFA"
                color: "white"
                font.bold: true
                font.pixelSize: 13
            }
        }

        onClicked: {
            if (reportReady) reportPanel.open()
            else             diagPanel.open()
        }
    }

    // ── Panneau de rapport ────────────────────────────────────────────
    Drawer {
        id: reportPanel
        parent: iface.mainWindow().contentItem
        width: Math.min(parent.width * 0.95, 520)
        height: parent.height * 0.85
        edge: Qt.BottomEdge

        // Filtre sévérité (sur le Drawer pour que reportPanel.severityFilter résolve)
        property string severityFilter: "Tout"

        background: Rectangle { color: Theme.mainBackgroundColor; radius: 12 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            // En-tête
            RowLayout {
                Layout.fillWidth: true
                Rectangle { width: 8; height: 40; radius: 4; color: report && report.is_valid ? "#2e7d32" : "#c62828" }
                Column {
                    Layout.fillWidth: true; Layout.leftMargin: 8; spacing: 2
                    Text { text: "Rapport de validation IFE"; font.pixelSize: 18; font.bold: true; color: Theme.mainTextColor }
                    Text {
                        text: report ? report.genere_le.replace("T", " ").replace("Z", " UTC") : ""
                        font.pixelSize: 12; color: Theme.secondaryTextColor
                    }
                }
                Rectangle {
                    width: badgeTxt.implicitWidth + 16; height: 28; radius: 14
                    color: report && report.is_valid ? "#e8f5e9" : "#ffebee"
                    Text {
                        id: badgeTxt; anchors.centerIn: parent
                        text: report ? (report.is_valid ? "VALIDE" : "INVALIDE") : ""
                        font.pixelSize: 12; font.bold: true
                        color: report && report.is_valid ? "#2e7d32" : "#c62828"
                    }
                }
            }

            // Compteurs
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: report ? [
                        { label: "Erreurs",        count: report.error_count,                     color: "#c62828", bg: "#ffebee" },
                        { label: "Avertissements", count: report.warning_count,                   color: "#e65100", bg: "#fff3e0" },
                        { label: "Couches",        count: (report.layers_processed || []).length, color: "#1565c0", bg: "#e3f2fd" }
                    ] : []
                    Rectangle {
                        Layout.fillWidth: true; height: 56; radius: 8; color: modelData.bg
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.count; font.pixelSize: 22; font.bold: true; color: modelData.color }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.pixelSize: 10; color: modelData.color }
                        }
                    }
                }
            }

            // Filtre sévérité
            Row {
                spacing: 6
                Repeater {
                    model: ["Tout", "Erreur", "Avertissement"]
                    delegate: Rectangle {
                        width: chipTxt.implicitWidth + 16; height: 28; radius: 14
                        color: reportPanel.severityFilter === modelData ? Theme.mainColor : Theme.mainBackgroundColor
                        border.color: Theme.mainColor; border.width: 1
                        Text { id: chipTxt; anchors.centerIn: parent; text: modelData; font.pixelSize: 12; color: reportPanel.severityFilter === modelData ? "white" : Theme.mainTextColor }
                        MouseArea { anchors.fill: parent; onClicked: reportPanel.severityFilter = modelData }
                    }
                }
            }

            // Liste anomalies
            ListView {
                id: issueList
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 6
                model: {
                    if (!report || !report.issues) return []
                    var f = reportPanel.severityFilter
                    if (f === "Tout")    return report.issues
                    if (f === "Erreur") return report.issues.filter(function(i){ return i.severity === "error" })
                    return report.issues.filter(function(i){ return i.severity === "warning" })
                }
                delegate: Rectangle {
                    width: issueList.width
                    height: issueCol.implicitHeight + 16
                    radius: 6
                    color: modelData.severity === "error" ? "#fff5f5" : "#fff8f0"
                    border.color: modelData.severity === "error" ? "#ffcdd2" : "#ffe0b2"
                    border.width: 1
                    Column {
                        id: issueCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        spacing: 4
                        RowLayout {
                            width: parent.width
                            Text { text: modelData.severity === "error" ? "✕" : "⚠"; font.pixelSize: 14; color: modelData.severity === "error" ? "#c62828" : "#e65100" }
                            Text { Layout.fillWidth: true; text: "[" + (modelData.layer || "—") + "] " + (modelData.code || ""); font.pixelSize: 11; font.bold: true; color: modelData.severity === "error" ? "#c62828" : "#e65100"; elide: Text.ElideRight }
                        }
                        Text { width: parent.width; text: modelData.message || ""; font.pixelSize: 12; color: Theme.mainTextColor; wrapMode: Text.WordWrap }
                        Text {
                            visible: modelData.fields && modelData.fields.length > 0
                            width: parent.width
                            text: "Champs : " + (modelData.fields || []).join(", ")
                            font.pixelSize: 11; color: Theme.secondaryTextColor; wrapMode: Text.WordWrap
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: issueList.count === 0 && reportReady
                    text: reportPanel.severityFilter === "Tout" ? "Aucune anomalie" : "Aucune anomalie pour ce filtre"
                    color: Theme.secondaryTextColor; font.pixelSize: 14
                }
            }

            Button { Layout.fillWidth: true; text: "Fermer"; onClicked: reportPanel.close() }
        }
    }

    // ── Panneau diagnostic (si le bouton reste gris) ──────────────────
    Drawer {
        id: diagPanel
        parent: iface.mainWindow().contentItem
        width: Math.min(parent.width * 0.95, 480)
        height: parent.height * 0.82
        edge: Qt.BottomEdge

        background: Rectangle { color: Theme.mainBackgroundColor; radius: 12 }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text { text: "Diagnostic Rapport IFE"; font.pixelSize: 18; font.bold: true; color: Theme.mainTextColor }
            Text {
                Layout.fillWidth: true
                // Dérivé de l'état plutôt que mémorisé dans diagMessage : rien
                // à restaurer quand l'attente se termine sans rien changer.
                text: root.waiting ? "Veuillez patienter — interrogation du serveur…"
                                   : root.diagMessage
                font.pixelSize: 13; color: Theme.mainTextColor; wrapMode: Text.WordWrap
            }

            GridLayout {
                columns: 2; columnSpacing: 12; rowSpacing: 6; Layout.fillWidth: true

                Text { text: "Utilisateur"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text {
                    Layout.fillWidth: true
                    text: root.cloudUsername !== "" ? root.cloudUsername : "(non connecté)"
                    font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                    color: root.cloudUsername !== "" ? Theme.mainTextColor : "#c62828"
                }

                Text { text: "Serveur"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text {
                    Layout.fillWidth: true
                    text: root.serverUrl !== "" ? root.serverUrl : "(inconnu)"
                    font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                    color: root.serverUrl !== "" ? Theme.mainTextColor : "#c62828"
                }

                Text { text: "Session"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text {
                    text: root.loginInFlight ? "authentification…"
                        : (root.authToken !== "" ? "authentifié" : "non authentifié")
                    font.pixelSize: 12
                    color: root.authToken !== "" ? Theme.mainTextColor : "#c62828"
                }

                Text { text: "Expire le"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text {
                    Layout.fillWidth: true
                    text: root.tokenExpiresAt !== "" ? root.tokenExpiresAt : "—"
                    font.pixelSize: 12; color: Theme.mainTextColor; wrapMode: Text.WrapAnywhere
                }

                Text { text: "projectId"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text {
                    Layout.fillWidth: true
                    text: root.projectId !== "" ? root.projectId : "(vide)"
                    font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                    color: root.projectId !== "" ? Theme.mainTextColor : "#c62828"
                }

                Text { text: "HTTP login"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text { text: root.diagLoginStatus; font.pixelSize: 12; color: Theme.mainTextColor }

                Text { text: "HTTP paquet"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text { text: root.diagPackageStatus; font.pixelSize: 12; color: Theme.mainTextColor }

                Text { text: "HTTP rapport"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text { text: root.diagReportStatus; font.pixelSize: 12; color: Theme.mainTextColor }

                Text { text: "Màj données"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text {
                    Layout.fillWidth: true
                    text: root.diagPackagedAt
                    font.pixelSize: 12; color: Theme.mainTextColor; wrapMode: Text.WrapAnywhere
                }

                Text { text: "Deltas en attente"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text {
                    text: root.diagDeltaCount
                    font.pixelSize: 12
                    color: root.reportStale ? "#e65100" : Theme.mainTextColor
                }

                Text { text: "Chemin projet"; font.pixelSize: 12; color: Theme.secondaryTextColor }
                Text {
                    Layout.fillWidth: true
                    text: root.projectHome !== "" ? root.projectHome : "(vide)"
                    font.pixelSize: 11; wrapMode: Text.WrapAnywhere
                    color: root.projectHome !== "" ? Theme.secondaryTextColor : "#c62828"
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true; spacing: 8

                // Seule porte de sortie quand l'utilisateur a annulé ou saisi un
                // mauvais mot de passe : authFailed bloque la réouverture
                // automatique, il faut donc un geste explicite pour réessayer.
                Button {
                    Layout.fillWidth: true
                    text: "Se connecter"
                    visible: root.authToken === "" && !root.loginInFlight
                    onClicked: {
                        root.authFailed = false
                        root.ensureToken()
                    }
                }
                Button {
                    Layout.fillWidth: true; text: "Rafraîchir"
                    // checkPackage() sort immédiatement tant que waitingForSync
                    // est levé : sans ça le bouton paraîtrait sans effet.
                    enabled: !root.waiting && root.authToken !== ""
                    onClicked: { root.lastSeenPackagedAt = ""; root.checkDeltafile(); root.checkPackage() }
                }
                Button { Layout.fillWidth: true; text: "Fermer"; onClicked: diagPanel.close() }
            }
        }
    }
}
