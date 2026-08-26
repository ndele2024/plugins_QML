# Plugin QField « IFA 2.0 — Menu »

Point d'entrée du programme IFA 2.0 sur le terrain. Le plugin ajoute un bouton
**démarrer** (▶) dans la barre d'outils de QField ; un appui ouvre le menu
principal, d'où partent toutes les fonctions.

```
IFA 2.0
├── Gestionnaire de projet
│   ├── Créer un projet                    → FenetreCreerProjet.qml     (squelette)
│   └── Modifier / Afficher un projet      → FenetreModifierProjet.qml  (squelette)
└── Gestionnaire d'unité d'échantillonnage
    ├── Créer une UE                       → FenetreCreerUE.qml         (fonctionnel)
    └── Consulter une UE                   → FenetreConsulterUE.qml     (squelette)
```

---

## 1. Fichiers

| Fichier | Rôle |
|---|---|
| `main.qml` | Point d'entrée : bouton de la barre d'outils, **registre des menus**, routage vers les fenêtres. |
| `MenuPrincipal.qml` | La fenêtre du menu. Se construit entièrement à partir du registre — ne contient aucune commande en dur. |
| `IfaPopup.qml` | Coquille commune des fenêtres : responsive, en-tête coloré, contenu défilant, pied d'actions. |
| `IfaCommande.qml` | Une ligne de commande cliquable du menu. |
| `IfaChantier.qml` | Bandeau « fonction en cours de développement » des squelettes. |
| `Referentiels.qml` | Listes de référence (régions, types d'UE) et accès défensifs aux couches. |
| `SelecteurEmprise.qml` | Tracé d'une emprise polygonale sur la carte — voir §6. |
| `ServiceUE.qml` | Accès aux unités d'échantillonnage — **bouchon**, voir §7. |
| `TableauUE.qml` | Liste des unités : tableau sur grand écran, fiches sur téléphone. |
| `EtiquetteVerrou.qml` | Pastille d'état de verrouillage d'une UE. |
| `FenetreCreerUE.qml` | Formulaire de création d'une UE — **le modèle à suivre** pour les autres. |
| `Fenetre*.qml` | Une fenêtre par commande. |
| `metadata.txt`, `icon.svg` | Identité du plugin dans la liste des plugins de QField. |
| `install.py` | Installation (plugin d'application, plugin de projet, ou archive .zip). |

---

## 2. Installation

### Pendant le développement — plugin d'application (recommandé)

```powershell
python install.py
```

Le dossier est copié dans le répertoire des plugins de QField
(`%APPDATA%\OPENGIS.ch\QField\plugins\ifa_menu\` sous Windows — à côté de
`cloud_projects\`). Le plugin est alors actif **quel que soit le projet ouvert**,
ce qui évite de republier un projet à chaque essai.

Ensuite, dans QField :

1. **Réglages → Plugins** → activer « IFA 2.0 — Menu ».
2. QField demande l'autorisation d'exécuter le plugin : accepter.
3. Le bouton ▶ apparaît dans la barre d'outils.

### Pour livrer avec un projet — plugin de projet

```powershell
python install.py --projet "C:\Users\...\QField\cloud_projects\admin\<uuid>"
```

Copie tous les `.qml` à côté du projet et crée le fichier `<nom_du_projet>.qml`
que QField recherche. Publier ensuite via QGIS Desktop → QFieldSync.

### Pour distribuer — archive

```powershell
python install.py --zip
```

Produit `ifa_menu.zip`, installable depuis une URL (Réglages → Plugins), ou à
distance via `pluginManager.installFromUrl()`.

---

## 3. Ajouter une commande

Le menu est **piloté par les données** : `MenuPrincipal.qml` ne connaît aucune
commande, il affiche le registre `sections` de `main.qml`. Ajouter une commande
demande donc deux gestes, jamais plus.

**1.** Créer `FenetreMaCommande.qml` en partant de `FenetreCreerProjet.qml`
(squelette) ou de `FenetreCreerUE.qml` (formulaire complet) :

```qml
IfaPopup {
  id: fenetre

  titre: qsTr("Ma commande")
  icone: "ic_add_white_24dp"
  accent: Theme.mainColor

  Label {
    Layout.fillWidth: true
    text: qsTr("Bonjour")
  }

  actions: [
    QfButton {
      text: qsTr("Fermer")
      onClicked: fenetre.close()
    }
  ]
}
```

**2.** Déclarer la commande dans `sections`, `main.qml` :

```qml
{
  "id": "ma_commande",
  "titre": qsTr("Ma commande"),
  "soustitre": qsTr("Ce qu'elle fait"),
  "icone": "ic_add_white_24dp",
  "fichier": "FenetreMaCommande.qml"
}
```

Laisser `"fichier": ""` marque la commande « à venir » dans le menu : elle reste
visible et affiche un message au lieu d'ouvrir une fenêtre.

Ajouter un **menu** entier suit la même logique : une entrée de plus dans
`sections`, avec sa propre liste de `commandes`.

### Ce qui est disponible dans une fenêtre

| Élément | Usage |
|---|---|
| `referentiels` | Injecté automatiquement — voir §4. |
| `avertir(message, type)` | Notification QField. `type` : `"info"`, `"warning"`, `"error"`. |
| `compact` | `true` sur écran étroit (< 520 px), pour adapter la mise en page. |
| `accent`, `surAccent` | Couleur d'accent et couleur de texte contrastée correspondante. |
| `actions` | Boutons du pied de page. |
| `margeContenu` | Marge intérieure (16 px par défaut). |

Le contenu déclaré dans la fenêtre est empilé dans un `ColumnLayout` : utiliser
les propriétés attachées `Layout.*` sur chaque enfant.

---

## 4. Referentiels

Instance unique créée dans `main.qml`, injectée dans chaque fenêtre. Centralise
les listes de référence et **tous les accès aux couches**.

| Membre | Description |
|---|---|
| `regions` | Les 17 régions administratives (`{ code, nom }`). |
| `typesUe` | Les 13 types d'UE (`{ code, nom }`). |
| `couche(nom)` | La couche, ou `null` si absente. **Toujours passer par là** : `mapLayersByName(nom)[0]` lève une erreur quand la couche n'existe pas. |
| `chargerProjets()` | Lit `proje_sonda` (projets en production, triés par année décroissante). |
| `projetsDeLaRegion(code)` | Projets d'une région ; tous si `code` est vide. |
| `rechercherLce(no)` | `{ coucheDisponible, trouve, nom, mrc }` depuis la couche `LCE`. |
| `regionParGps()` | Code de région déduit de la position, via la couche `regio_s`. |
| `variableProjet(nom)` / `definirVariableProjet(nom, valeur)` | Variables de projet QGIS. |

Toutes ces fonctions sont **défensives** : couche absente → valeur neutre, jamais
d'erreur. Le plugin reste utilisable sur un projet incomplet, et une seule
commande dégradée n'empêche pas d'utiliser les autres.

> Les listes `regions` et `typesUe` sont pour l'instant codées en dur, comme dans
> le plugin d'origine. Étape suivante : les lire depuis les couches de référence
> (`ifa_referentiels`) ou depuis les points d'accès QFieldCloud.

---

## 5. Couches attendues par « Créer une UE »

| Couche | Rôle | Si absente |
|---|---|---|
| `mesurage` | Couche de saisie ouverte à la validation. | Bandeau d'avertissement, bouton « Créer » désactivé. |
| `proje_sonda` | Liste des projets. | Liste de projets vide. |
| `LCE` | Recherche du plan d'eau par n° officiel. | Message « vérification impossible ». |
| `regio_s` | Présélection de la région par GPS. | Pas de présélection. |

À la validation, la fenêtre pose les variables de projet `code_region`,
`code_formulaire`, `type_formulaire`, `code_lce`, `une_code_ident`,
`code_projet` (elles alimentent les valeurs par défaut du formulaire QGIS), puis
ouvre le tiroir de saisie sur une nouvelle entité de `mesurage`.

---

## 6. Filtre des données à embarquer

Le bloc « Données à embarquer », en bas du formulaire « Créer une UE », choisit
le sous-ensemble de données extrait dans les GeoPackage du projet dérivé. Trois
critères, repris de `extract_ipe_subset.py` avec le n° de plan d'eau en plus :

| Critère | Source de la valeur |
|---|---|
| **Région** | La région administrative saisie plus haut. |
| **N° de plan d'eau** | Le n° LCE saisi plus haut. |
| **Emprise personnalisée** | Un polygone tracé sur la carte. |

Le critère retenu est enregistré en variables de projet :

| Variable | Contenu |
|---|---|
| `filtre_mode` | `region`, `lce` ou `emprise`. |
| `filtre_valeur` | Code de région ou n° LCE selon le mode ; vide en mode emprise. |
| `filtre_emprise_wkt` | `POLYGON((…))` en **EPSG:4326**. |
| `filtre_emprise_bbox` | `[xmin, ymin, xmax, ymax]` en EPSG:4326, JSON. |

Le WKT est produit en EPSG:4326 et non dans le CRS des données : c'est le
format attendu par le champ `extent` du seed QFieldCloud, et cela laisse au
serveur le soin de reprojeter vers le CRS de la base.

### Tracer une emprise

Un plugin ne peut pas s'insérer dans la chaîne d'événements tactiles de la
carte : poser un calque transparent pour capter les clics bloquerait le
déplacement et le zoom. `SelecteurEmprise` reprend donc la méthode native de
QField pour numériser sans GPS.

1. « Tracer sur la carte » referme la fenêtre et pose un calque sur la carte :
   croix de visée au centre, bandeau d'aide en haut, barre d'actions en bas.
2. L'utilisateur déplace la carte pour amener la croix sur un sommet, puis
   appuie sur **Ajouter**. Le polygone se dessine au fur et à mesure.
3. **Emprise visible** remplace le tracé par un rectangle correspondant aux
   quatre coins de la vue — utile quand un cadrage grossier suffit. Les coins
   étant convertis individuellement, le résultat reste juste même carte pivotée.
4. **Terminer** (3 sommets minimum) referme le calque et rouvre le formulaire,
   avec la saisie intacte.

La fenêtre n'est pas détruite pendant le tracé : le `Loader` de `main.qml` ne
libère une fenêtre qu'au chargement de la suivante, précisément pour que ce
va-et-vient préserve la saisie en cours.

Pour réutiliser le sélecteur dans une autre fenêtre :

```qml
SelecteurEmprise {
  id: selecteur
  accent: fenetre.accent
  onValide: function (wkt, bbox, nombreSommets) { fenetre.open(); /* … */ }
  onAnnule: fenetre.open()
  Component.onDestruction: selecteur.reinitialiserAffichage()
}

// déclenchement
fenetre.close();
selecteur.demarrer(sommetsExistants);   // argument facultatif : reprise d'un tracé
```

Le `Component.onDestruction` n'est pas facultatif : pendant un tracé, le calque
est rattaché au conteneur de la carte et survivrait sinon à la fenêtre qui l'a
créé.

---

## 7. Consulter une UE

La fenêtre enchaîne deux étapes.

**Étape 1 — filtre.** Quatre critères : région, n° de plan d'eau, zone
personnalisée (le `SelecteurEmprise` du §6, réutilisé tel quel), ou code d'UE
exact (`une_code_ident`, ex. `02-12777-IPE`).

**Étape 2 — résultats.** Un rappel du filtre avec un bouton « Modifier », puis
la liste des unités. Les colonnes reprennent la table `unite_echan` :

| Colonne | Champ |
|---|---|
| Code UE | `une_code_ident` |
| Type d'UE | `tue_nom` (via `tue_code_ident`) |
| Verrou | `une_ind_verro` (`O`/`N`) + `une_nom_propr_verro` en infobulle |
| Créée le / Par | `une_date_creat` / `une_code_utili_creat` |
| Modifiée le | `une_date_maj` |
| Actions | ouvrir et verrouiller · ouvrir sans verrouiller · supprimer |

Une unité déjà verrouillée voit « ouvrir et verrouiller » et « supprimer »
désactivés, l'infobulle nommant le détenteur du verrou. La suppression passe
obligatoirement par une confirmation qui nomme l'unité.

`TableauUE` bascule en fiches empilées sous 640 px de large. Un tableau de neuf
colonnes n'est pas seulement illisible sur un téléphone : atteindre la corbeille
demanderait un défilement horizontal, geste propice aux suppressions
accidentelles.

### ⚠️ Le service est un bouchon

`ServiceUE.qml` **fabrique les résultats localement** — le point d'accès
QFieldCloud n'existe pas encore. Le générateur utilise les formats relevés dans
les données réelles (codes `RR-NNNNN-TYPE`, `une_ind_verro` valant `O`/`N`,
horodatages ISO 8601, codes d'utilisateur à six caractères) et il est **à
graine** : un même filtre rend toujours le même jeu de données, ce qui rend les
essais reproductibles.

Le jour où le backend arrive, **seul ce fichier change** : ni `FenetreConsulterUE`
ni `TableauUE` n'ont à bouger. Passer `simulation` à `false` et implémenter
`rechercher()` en respectant le contrat décrit dans l'en-tête du fichier.

Rappel du piège d'authentification : le plugin doit envoyer un `User-Agent`
du type `sdk|ifa-plugin/1.0`. Un en-tête commençant par `qfield|` ferait expirer
le jeton de QField lui-même (`AuthToken.single_token_clients`, côté serveur) et
déconnecterait le technicien.

Deux points restent à traiter côté serveur avant la mise en service :

- **la pagination** — `unite_echan` compte environ 142 000 lignes ; un filtre par
  région en renvoie encore plusieurs milliers ;
- **les trois actions** — verrouillage, ouverture en lecture et suppression sont
  aujourd'hui de simples notifications (voir les `TODO` en fin de
  `FenetreConsulterUE.qml`).

---

## 8. Bon à savoir

**Recharger après modification.** QField ne contourne le cache QML que pour le
fichier principal du plugin. Les composants voisins (`MenuPrincipal.qml`,
`IfaPopup.qml`, …) sont chargés normalement : après les avoir modifiés,
**relancer QField**. Désactiver/réactiver le plugin ne suffit pas toujours.

**Autorisation.** QField demande une autorisation au premier chargement d'un
plugin. Elle est mémorisée par chemin d'installation : réinstaller ailleurs la
redemande.

**API non documentée.** `iface.findItemByObjectName()` sert à atteindre
`dashBoard`, `overlayFeatureFormDrawer` et `positionSource`. Ces noms ne font pas
partie de l'API publique des plugins : une mise à jour de QField peut les
renommer. Tous les appels sont donc gardés et signalent un message clair plutôt
que de planter. Noms vérifiés sur QField `f7123fc` (31 juillet 2026).

**Couleurs.** Les accents sont désignés par le **nom** d'une couleur du thème
(`"mainColor"`, `"cloudColor"`), pas par une valeur `#rrggbb` : le rendu suit
ainsi le thème clair comme le thème sombre. `IfaPopup.surAccent` calcule
automatiquement une couleur de texte lisible sur l'accent choisi.

**Cible tactile.** Les lignes de commande font au moins 64 px de haut, pour
rester utilisables avec des gants.
