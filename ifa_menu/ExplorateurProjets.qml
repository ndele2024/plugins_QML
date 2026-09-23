// =============================================================================
//  ExplorateurProjets — parcourt `cloud_projects` et en tire les projets
// =============================================================================
//  QField range les projets infonuagiques téléchargés selon une arborescence
//  fixe, sous l'une de ses racines de données :
//
//      <racine>/cloud_projects/<utilisateur>/<id du projet>/<projet>.qgz
//
//  Ce composant la parcourt sur trois niveaux et publie ce qu'il trouve dans
//  `projets`. C'est la seule source qui réponde vraiment à « déjà synchronisé
//  sur l'appareil » : elle voit un projet téléchargé même s'il n'a jamais été
//  ouvert — le cas de l'unité qu'on vient de préparer.
//
//  ---------------------------------------------------------------------------
//  POURQUOI UN FICHIER À PART
//  ---------------------------------------------------------------------------
//  `Qt.labs.folderlistmodel` est un module de Qt, pas de QField, et rien ne
//  garantit qu'une version donnée l'embarque. Un import manquant ne se rattrape
//  pas : il empêche le fichier entier de se charger. En l'isolant ici, celui qui
//  s'en sert le charge par un `Loader` et se contente d'un message si le module
//  manque, au lieu de devenir inutilisable.
//
//  ---------------------------------------------------------------------------
//  ACTUELLEMENT SANS APPELANT
//  ---------------------------------------------------------------------------
//  `ProjetsLocaux` s'en servait pour lister les projets de l'appareil, et
//  « Créer une UE » pour guetter l'arrivée d'un projet téléchargé. Ni l'un ni
//  l'autre n'existent plus : le fichier est conservé parce que c'est la seule
//  chose qui sache *où* QField range ses projets (`racinesCandidates()`) et
//  comment lire cette arborescence — une connaissance qui a coûté cher à
//  établir et qui resservira au prochain besoin.
//
//  ---------------------------------------------------------------------------
//  POURQUOI UN SEUL MODÈLE, PILOTÉ À LA MAIN
//  ---------------------------------------------------------------------------
//  `FolderListModel` lit un répertoire de façon asynchrone : on lui donne un
//  dossier, on attend `Ready`, on lit. Imbriquer trois modèles donnerait trois
//  niveaux de `Repeater` dont la mise en page se défend mal. Un seul modèle et
//  une file d'attente font le même parcours, en restant lisibles.
//
//  Le rendez-vous entre `folder` et `Ready` se tient sur un drapeau, **pas** sur
//  une comparaison d'URL. Une version précédente vérifiait que `lecteur.folder`
//  valait bien l'URL demandée : Qt ne rend pas la chaîne sous la forme qu'on lui
//  a donnée — barre finale, `%20` décodés — la comparaison échouait toujours, et
//  le parcours s'arrêtait au premier dossier sans jamais signaler sa fin.
//
//  Une minuterie de sûreté clôt le parcours si un dossier ne répond pas : mieux
//  vaut une liste partielle et un diagnostic affiché qu'une attente sans fin.
// =============================================================================

import QtQuick
import Qt.labs.folderlistmodel

Item {
  id: explorateur

  // ---------------------------------------------------------------------------
  //  API publique
  // ---------------------------------------------------------------------------
  // Projets trouvés : { titre, chemin, utilisateur, identifiant }.
  readonly property alias projets: trouves

  // Compte dont les projets passent en tête. Un appareil peut porter les
  // projets de plusieurs comptes ; celui qui est connecté est le seul qui
  // intéresse le technicien sur le moment.
  property string utilisateurPrefere: ""

  // Journal du parcours, affichable tel quel quand rien n'est trouvé.
  property var trace: []

  signal termine(int nombre)

  // `explorer(["C:/…/QField", …])` — les racines de données à sonder.
  function explorer(racines) {
    trouves.clear();
    trace = [];
    file = [];
    courant = null;
    attendu = false;

    for (let i = 0; i < racines.length; ++i) {
      const racine = ("" + racines[i]).replace(/[\\\/]+$/, "");

      if (racine !== "") {
        file.push({
          "url": versUrl(racine + "/cloud_projects"),
          "chemin": racine + "/cloud_projects",
          "niveau": 0,
          "utilisateur": "",
          "identifiant": ""
        });
      }
    }

    suivant();
  }

  // ---------------------------------------------------------------------------
  //  Interne
  // ---------------------------------------------------------------------------
  // File des dossiers restant à lire. Niveau 0 = `cloud_projects` (ses enfants
  // sont des utilisateurs), 1 = un utilisateur (ses enfants sont des projets),
  // 2 = un projet (on y cherche le fichier .qgz).
  property var file: []

  property var courant: null

  // Vrai entre le moment où l'on donne un dossier au modèle et celui où on l'a
  // lu. C'est tout ce qui sépare un `Ready` attendu d'un `Ready` en retard.
  property bool attendu: false

  ListModel {
    id: trouves
  }

  FolderListModel {
    id: lecteur

    showDirs: true
    showFiles: true
    showDotAndDotDot: false
    showHidden: false
    sortField: FolderListModel.Name

    onStatusChanged: {
      if (status === FolderListModel.Ready)
        explorateur.absorber();
    }
  }

  // Un dossier qui ne répond pas ne doit pas laisser le parcours en suspens.
  Timer {
    id: surete

    interval: 4000
    repeat: false

    onTriggered: {
      iface.logMessage("[IFA] parcours interrompu : " + (explorateur.courant ? explorateur.courant.chemin : "?") + " n'a pas repondu");
      explorateur.attendu = false;
      explorateur.courant = null;
      explorateur.file = [];
      explorateur.termine(trouves.count);
    }
  }

  // ---------------------------------------------------------------------------
  //  Où QField range ses projets
  // ---------------------------------------------------------------------------
  //  `platformUtilities.appDataDirs()` ne suffit pas : sa documentation dit
  //  « répertoires où sont cherchées les *données utilisateur* — pg_service.conf,
  //  configuration d'authentification, grilles », et sous Windows ce sont les
  //  dossiers « QField Documents ». Les projets infonuagiques vivent ailleurs :
  //
  //      C:/Users/<compte>/AppData/Roaming/OPENGIS.ch/QField/cloud_projects
  //
  //  D'où une liste de candidats plutôt qu'une racine unique : ce que QField
  //  déclare, plus l'emplacement standard de Windows reconstitué à partir du
  //  dossier personnel — lui-même déduit d'un chemin que QField nous donne, ou
  //  à défaut de l'emplacement du greffon. Un candidat qui n'existe pas ne
  //  coûte qu'un dossier vide de plus à lire.
  function racinesCandidates() {
    const vus = {};
    const sortie = [];

    function ajouter(chemin) {
      const p = normaliser(chemin);

      if (p === "" || vus[p])
        return;

      vus[p] = true;
      sortie.push(p);
    }

    // 1. Ce que QField déclare. Suffisant sur Android, où tout vit au même
    //    endroit ; pas sous Windows.
    let declarees = [];

    try {
      declarees = platformUtilities.appDataDirs();
    } catch (e) {
      iface.logMessage("[IFA] appDataDirs() indisponible : " + e);
    }

    for (let i = 0; declarees && i < declarees.length; ++i)
      ajouter(declarees[i]);

    try {
      ajouter(platformUtilities.applicationDirectory());
    } catch (e) {
      iface.logMessage("[IFA] applicationDirectory() indisponible : " + e);
    }

    // 2. L'emplacement standard de Windows, reconstitué à partir du dossier
    //    personnel. Celui-ci se lit dans n'importe lequel des chemins ci-dessus
    //    — ou, s'il n'y en a aucun, dans l'emplacement de ce fichier même.
    const pistes = sortie.slice();
    pistes.push(normaliser(("" + Qt.resolvedUrl(".")).replace(/^file:\/+/, "/")));

    for (let j = 0; j < pistes.length; ++j) {
      const maison = pistes[j].match(/^(.*\/Users\/[^\/]+)(\/|$)/);

      if (maison)
        ajouter(maison[1] + "/AppData/Roaming/OPENGIS.ch/QField");
    }

    return sortie;
  }

  function normaliser(chemin) {
    const p = ("" + chemin).replace(/\\/g, "/").replace(/\/+$/, "");

    // « /C:/… » vient d'une URL de fichier ; la forme canonique retenue ici est
    // « C:/… », faute de quoi le même dossier compterait deux fois.
    return p.replace(/^\/([A-Za-z]:)/, "$1");
  }

  function versUrl(chemin) {
    let p = ("" + chemin).replace(/\\/g, "/");

    if (p.indexOf("file:") === 0)
      return p;

    // Un chemin Windows commence par « C: » : l'URL de fichier en demande
    // trois barres obliques, d'où la barre ajoutée devant.
    if (p.indexOf("/") !== 0)
      p = "/" + p;

    // Les chemins d'ici portent des espaces — « OneDrive - QC380 »,
    // « QField Documents ». `encodeURI()` les code sans toucher aux « / » ni
    // aux « : », qui doivent rester tels quels dans une URL de fichier.
    return "file://" + encodeURI(p);
  }

  function suivant() {
    if (file.length === 0) {
      courant = null;
      attendu = false;
      surete.stop();
      termine(trouves.count);
      return;
    }

    courant = file.shift();
    attendu = true;
    surete.restart();
    lecteur.folder = courant.url;
  }

  function absorber() {
    // Un `Ready` qu'on n'attend pas — dossier précédent, ou modèle qui se
    // signale de lui-même — ne doit pas faire avancer la file.
    if (!courant || !attendu)
      return;

    attendu = false;
    surete.stop();

    const niveau = courant.niveau;
    const lu = lecteur.count;

    trace.push("[" + niveau + "] " + courant.chemin + " → " + lu);
    iface.logMessage("[IFA] lu " + courant.chemin + " : " + lu + " entree(s)");

    for (let i = 0; i < lu; ++i) {
      const nom = "" + lecteur.get(i, "fileName");
      const chemin = "" + lecteur.get(i, "filePath");
      const estDossier = lecteur.get(i, "fileIsDir") === true;

      if (niveau < 2) {
        if (estDossier) {
          const entree = {
            "url": versUrl(chemin),
            "chemin": chemin,
            "niveau": niveau + 1,
            "utilisateur": niveau === 0 ? nom : courant.utilisateur,
            "identifiant": niveau === 1 ? nom : courant.identifiant
          };

          // Le parcours est en largeur : l'ordre dans lequel les comptes sont
          // mis en file est celui dans lequel leurs projets ressortiront.
          if (niveau === 0 && utilisateurPrefere !== "" && nom === utilisateurPrefere)
            file.unshift(entree);
          else
            file.push(entree);
        }

        continue;
      }

      // Niveau 2 : le fichier projet. QField en dépose un seul par dossier.
      if (estDossier)
        continue;

      const minuscules = nom.toLowerCase();

      if (!minuscules.endsWith(".qgz") && !minuscules.endsWith(".qgs"))
        continue;

      trouves.append({
        "titre": nom.substring(0, nom.lastIndexOf(".")),
        "chemin": chemin,
        "utilisateur": courant.utilisateur,
        "identifiant": courant.identifiant
      });
    }

    suivant();
  }
}
