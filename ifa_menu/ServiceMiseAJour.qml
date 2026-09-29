// =============================================================================
//  ServiceMiseAJour — le plugin se tient à jour depuis le serveur QFieldCloud
// =============================================================================
//  Le serveur publie la version courante du plugin (page d'administration
//  « Plugin QField IFA ») à deux adresses publiques :
//
//      <serveur>/api/v1/ifa/plugin/metadata.txt    la version publiée
//      <serveur>/api/v1/ifa/plugin/ifa_menu.zip    l'archive
//
//  Au démarrage, le service lit la première, la compare à la version installée
//  et, si elle est plus récente, émet `miseAJourDisponible`. `installer()` fait
//  le reste par l'API de QField.
//
//  ---------------------------------------------------------------------------
//  LE PIÈGE : QFIELD DÉSACTIVE LE PLUGIN QU'IL MET À JOUR
//  ---------------------------------------------------------------------------
//  `pluginManager.installFromUrl()` appelle `disableAppPlugin()` sur le plugin
//  avant d'extraire l'archive, et ne le réactive pas : un plugin qui se met à
//  jour lui-même se retrouverait éteint, à réactiver à la main.
//
//  Ce qui le sauve (lu dans `pluginmanager.cpp`, v4.2.11) : le déchargement
//  passe par `deleteLater()`, et `installEnded` est émis DANS LA MÊME fonction,
//  avant tout retour à la boucle d'événements. Ce service est donc encore en
//  vie quand le signal arrive, et il appelle aussitôt `enableAppPlugin()` —
//  qui charge la nouvelle version (le cache QML est vidé au déchargement).
//
//  Surtout PAS de `Qt.callLater` dans ce chemin : il s'exécuterait après la
//  boucle d'événements, c'est-à-dire après la destruction de ce service.
//
//  ---------------------------------------------------------------------------
//  L'IDENTIFIANT DU PLUGIN
//  ---------------------------------------------------------------------------
//  QField nomme le dossier du plugin installé — et donc son `uuid` — d'après
//  le nom de l'archive téléchargée : `ifa_menu.zip` → `ifa_menu`. C'est aussi
//  le dossier qu'écrit `install.py`. Installé sous un autre nom (plugin de
//  projet, dossier renommé), le plugin ne se trouve pas dans la liste de
//  QField : le service le dit dans le journal et ne propose rien.
// =============================================================================

import QtQuick

import org.qfield

Item {
  id: service

  visible: false

  // ---------------------------------------------------------------------------
  //  Dépendances injectées
  // ---------------------------------------------------------------------------
  // Pour l'adresse du serveur — celle de la connexion QFieldCloud de QField.
  property var session: null

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  readonly property string nomPlugin: "ifa_menu"

  property string versionInstallee: ""
  property string versionPubliee: ""
  property bool installationEnCours: false

  // Vérifiée une fois par démarrage : le technicien qui a répondu « Plus
  // tard » ne doit pas être relancé à chaque ouverture de projet.
  property bool verifiee: false

  signal miseAJourDisponible(string versionInstallee, string versionPubliee)
  signal progression(string message)
  signal echec(string message)
  signal installee(string version)

  // ---------------------------------------------------------------------------
  //  Déclenchement
  // ---------------------------------------------------------------------------
  //  L'adresse du serveur n'est connue qu'une fois la connexion QFieldCloud de
  //  QField atteinte — pas au chargement d'un plugin d'application. On attend
  //  qu'elle le soit, sans insister au-delà d'une minute.
  property int essais: 0

  Timer {
    id: minuterieDemarrage

    interval: 5000
    repeat: true
    running: true

    onTriggered: {
      if (service.verifiee || ++service.essais > 12) {
        stop();
        return;
      }

      if (service.urlServeur() !== "") {
        stop();
        service.verifier();
      }
    }
  }

  // Le gestionnaire de plugins de QField, exposé à tout le QML de
  // l'application. Absent d'une version qui ne l'expose pas : rien n'est
  // alors proposé.
  readonly property var gestionnaire: typeof pluginManager !== "undefined" ? pluginManager : null

  Connections {
    target: service.gestionnaire
    ignoreUnknownSignals: true

    function onInstallProgress(avancement) {
      if (service.installationEnCours)
        service.progression(qsTr("Téléchargement de la version %1… %2 %").arg(service.versionPubliee).arg(Math.round(avancement * 100)));
    }

    // Voir l'en-tête : ce gestionnaire s'exécute alors que QField vient de
    // désactiver ce plugin. Tout doit se faire ici, tout de suite.
    function onInstallEnded(uuid, erreur) {
      if (!service.installationEnCours)
        return;

      service.installationEnCours = false;

      if (uuid !== service.nomPlugin) {
        const message = erreur ? erreur : qsTr("installation inattendue (%1)").arg(uuid);
        iface.logMessage("[IFA] mise a jour du plugin en echec : " + message);
        service.echec(qsTr("La mise à jour du plugin a échoué : %1").arg(message));
        return;
      }

      iface.logMessage("[IFA] plugin mis a jour en " + service.versionPubliee + " — reactivation");
      service.installee(service.versionPubliee);
      service.gestionnaire.enableAppPlugin(service.nomPlugin);
    }
  }

  // ===========================================================================
  //  API
  // ===========================================================================
  function urlServeur() {
    return session && session.urlServeur ? "" + session.urlServeur : "";
  }

  function verifier() {
    verifiee = true;

    if (!gestionnaire) {
      iface.logMessage("[IFA] mise a jour : gestionnaire de plugins de QField inaccessible");
      return;
    }

    versionInstallee = lireVersionInstallee();

    if (versionInstallee === "") {
      iface.logMessage("[IFA] mise a jour : plugin « " + nomPlugin + " » absent de la liste de QField (plugin de projet, ou dossier renomme ?) — aucune verification");
      return;
    }

    const xhr = new XMLHttpRequest();

    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE)
        return;

      if (xhr.status === 404) {
        iface.logMessage("[IFA] mise a jour : aucune version publiee sur le serveur");
        return;
      }

      if (xhr.status !== 200) {
        iface.logMessage("[IFA] mise a jour : lecture de la version impossible (HTTP " + xhr.status + ")");
        return;
      }

      service.comparer(service.versionDans(xhr.responseText));
    };

    xhr.open("GET", urlServeur() + "/api/v1/ifa/plugin/metadata.txt");
    xhr.send();
  }

  function installer() {
    if (!gestionnaire || installationEnCours || versionPubliee === "")
      return;

    installationEnCours = true;
    progression(qsTr("Téléchargement de la version %1…").arg(versionPubliee));
    iface.logMessage("[IFA] mise a jour du plugin vers " + versionPubliee);

    gestionnaire.installFromUrl(urlServeur() + "/api/v1/ifa/plugin/" + nomPlugin + ".zip");
  }

  // ===========================================================================
  //  Interne
  // ===========================================================================
  function comparer(publiee) {
    if (publiee === "") {
      iface.logMessage("[IFA] mise a jour : version publiee illisible");
      return;
    }

    versionPubliee = publiee;
    iface.logMessage("[IFA] plugin installe " + versionInstallee + ", publie " + publiee);

    if (comparerVersions(publiee, versionInstallee) > 0)
      miseAJourDisponible(versionInstallee, publiee);
  }

  // `version=0.2.0` dans le texte de metadata.txt.
  function versionDans(texte) {
    const lignes = ("" + texte).split(/\r?\n/);

    for (let i = 0; i < lignes.length; ++i) {
      const m = lignes[i].match(/^\s*version\s*=\s*([0-9.]+)\s*$/i);
      if (m)
        return m[1];
    }

    return "";
  }

  // -1, 0 ou 1, nombre par nombre : 0.10.0 est plus récent que 0.9.0.
  function comparerVersions(a, b) {
    const pa = ("" + a).split(".").map(Number);
    const pb = ("" + b).split(".").map(Number);
    const n = Math.max(pa.length, pb.length);

    for (let i = 0; i < n; ++i) {
      const x = pa[i] || 0;
      const y = pb[i] || 0;
      if (x !== y)
        return x > y ? 1 : -1;
    }

    return 0;
  }

  // Deux chemins, parce que QML ne sait pas toujours lire une liste de
  // `Q_GADGET` : `availableAppPlugins` d'abord, le modèle des plugins
  // ensuite (rôles `UuidRole` et `VersionRole` de `PluginModel`).
  function lireVersionInstallee() {
    try {
      const plugins = gestionnaire.availableAppPlugins;
      if (plugins && plugins.length !== undefined) {
        for (let i = 0; i < plugins.length; ++i) {
          if (plugins[i] && plugins[i].uuid === nomPlugin && plugins[i].version)
            return "" + plugins[i].version;
        }
      }
    } catch (e) {
      iface.logMessage("[IFA] mise a jour : availableAppPlugins illisible — " + e);
    }

    try {
      const modele = gestionnaire.pluginModel;
      const roleUuid = Qt.UserRole + 1;
      const roleVersion = Qt.UserRole + 11;

      for (let i = 0; modele && i < modele.rowCount(); ++i) {
        const index = modele.index(i, 0);
        if (modele.data(index, roleUuid) === nomPlugin)
          return "" + modele.data(index, roleVersion);
      }
    } catch (e) {
      iface.logMessage("[IFA] mise a jour : pluginModel illisible — " + e);
    }

    return "";
  }
}
