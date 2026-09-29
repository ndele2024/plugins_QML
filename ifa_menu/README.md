# Plugin QField « IFA 2.0 — Menu »

Point d'entrée du programme IFA 2.0 sur le terrain. Le plugin ajoute un bouton
**démarrer** (▶) dans la barre d'outils de QField ; un appui ouvre le menu
principal, d'où partent toutes les fonctions.

```
IFA 2.0
├── Gestionnaire de projet
│   ├── Créer un projet                    → FenetreCreerProjet.qml     (squelette)
│   └── Modifier / Afficher un projet      → FenetreModifierProjet.qml  (squelette)
├── Gestionnaire d'unité d'échantillonnage
│   ├── Créer une UE                       → FenetreCreerUE.qml         (fonctionnel)
│   └── Consulter une UE                   → FenetreConsulterUE.qml     (fonctionnel)
└── Validation des données
    └── Rapport de validation              → FenetreValidation.qml      (fonctionnel)
```

---

## 1. Fichiers

| Fichier | Rôle |
|---|---|
| `main.qml` | Point d'entrée : bouton de la barre d'outils, **registre des menus**, routage vers les fenêtres. |
| `MenuPrincipal.qml` | La fenêtre du menu. Se construit entièrement à partir du registre — ne contient aucune commande en dur. |
| `IfaPopup.qml` | Coquille commune des fenêtres : responsive, en-tête coloré, bandeau d'activité épinglé, contenu défilant, pied d'actions. |
| `IfaCommande.qml` | Une ligne de commande cliquable du menu. |
| `IfaChantier.qml` | Bandeau « fonction en cours de développement » des squelettes. |
| `ChoixCriteres.qml` | Rangée de pastilles cochables : la sélection **multicritère** des deux fenêtres de filtrage — voir §6 et §7. |
| `Referentiels.qml` | Listes de référence (régions, types d'UE) et accès défensifs aux couches. |
| `SelecteurEmprise.qml` | Tracé d'une emprise polygonale sur la carte — voir §6. |
| `SessionCloud.qml` | Jeton et appels authentifiés à QFieldCloud — voir §10. |
| `ServiceUE.qml` | Recherche des unités d'échantillonnage sur le serveur — voir §7. |
| `ServiceOuverture.qml` | Ouverture d'une UE dans QField : verrou, projet d'affichage, packaging — voir §7. |
| `ServiceFormulaire.qml` | Création de l'UE et préparation de son projet de saisie — voir §6. |
| `ServiceVerrou.qml` | Levée du verrou d'une UE, à la demande de son détenteur — voir §7 et §8. |
| `ServiceValidation.qml` | Guette les synchronisations et va chercher le rapport de validation — voir §8. |
| `FenetreValidation.qml` | Verdict, compteurs et anomalies du rapport — voir §8. |
| `DialogueDeverrouillage.qml` | Après une synchronisation : rendre l'unité, ou la garder — voir §8. |
| `DialogueRaisonVerrou.qml` | Saisie du motif du verrouillage, avec motifs suggérés. |
| `PasseurProjet.qml` | Télécharge le projet préparé par le serveur et l'ouvre à la place du projet courant — voir §6. |
| `DialogueAttente.qml` | Fenêtre d'attente centrée, du clic jusqu'à l'ouverture du projet — voir §6. |
| `DialogueProjetPret.qml` | Repli quand l'ouverture automatique échoue : le nom du projet, à ouvrir depuis l'écran « Projets » — voir §6. |
| `TableauUE.qml` | Liste des unités : tableau sur grand écran, fiches sur téléphone. |
| `ExplorateurProjets.qml` | Parcours de `cloud_projects` sur le disque. **Sans appelant aujourd'hui** : conservé pour ce qu'il sait de l'arborescence des projets. |
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
| `session` | Injectée automatiquement — appels authentifiés au serveur, voir §10. |
| `validation` | Injecté automatiquement — suivi de la validation, voir §8. |
| `passeur` | Injecté automatiquement — téléchargement et ouverture d'un projet QFieldCloud, voir §6. |
| `attente` | Injectée automatiquement — la fenêtre d'attente centrée, voir §6. |
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
| `proje_sonda` | Liste des projets. | Liste de projets vide. |
| `LCE` | Recherche du plan d'eau par n° officiel. | Message « vérification impossible ». |
| `regio_s` | Présélection de la région par GPS. | Pas de présélection. |

Aucune n'est indispensable : la saisie n'a plus lieu dans le projet ouvert, mais
dans le projet que le serveur prépare (§6). Ce qui manque vraiment à la fenêtre,
c'est une **session QFieldCloud** — sans elle, un bandeau le dit et « Créer »
reste désactivé.

---

## 6. Créer une UE : le projet de saisie

Un appui sur « Créer » ne remplit plus le projet ouvert. Il inscrit l'unité dans
la base, demande au serveur le projet `formulaire_UE_IFA` de l'utilisateur, puis
le télécharge et l'ouvre à la place du projet courant :

```
PasseurProjet.verifier()                  FenetreCreerUE  (avant tout appel)
      ↓  QField connecté, aucune modification en attente
POST /api/v1/ifa/formulaire/preparer/     ServiceFormulaire
      ↓  le serveur crée l'UE, clone le modèle, remplit le GeoPackage, package
GET  /api/v1/jobs/<id>/  (sondage)        ServiceFormulaire
      ↓  packaging terminé
téléchargement · ouverture                PasseurProjet
```

### L'unité est créée et verrouillée tout de suite

Avant même de préparer le projet, le serveur écrit la nouvelle unité dans
`ifa_data.unite_echan` et la **verrouille** au nom de l'utilisateur, avec pour
raison « nouvelle Unité d'échantillonnage ». C'est ce qui réserve son code :
l'identifiant est composé de la région, du n° de plan d'eau et du type, et deux
équipes qui visent le même plan d'eau le même jour composeraient le même.

La fenêtre envoie donc `une_code_ident` et `type_ue` **à part** des `variables`,
bien qu'ils y figurent aussi : ce qui entre dans la base métier ne doit pas
dépendre d'un dictionnaire libre dont le serveur ignore les clés inconnues. Le
type voyage par son libellé — c'est ce que porte `Referentiels.typesUe` — et le
serveur le résout en `tue_code_ident`.

Deux conséquences visibles depuis la fenêtre :

* un identifiant déjà porté par une unité du fonds est refusé (`409`), et le
  message invite à le modifier. Le cas est courant : le fonds contient des
  unités de 2009 sur les mêmes plans d'eau ;
* si la préparation du projet échoue *ensuite*, l'unité reste créée et tenue.
  Rejouer « Créer » avec le même identifiant **reprend** la création au lieu de
  buter dessus.

Le serveur retrouve — ou crée à partir du projet modèle
`v8_default_config_pkey_ObvervationGenTest` d'`ifa_team` — le projet
`formulaire_UE_IFA` **sous le compte de l'utilisateur**, et remplit son
GeoPackage des données choisies ci-dessous, lues dans le schéma `ifa_data`, la
nouvelle unité comprise. Voir le §5 du README de `qfieldcloud.ifa` pour ce qui
se passe côté serveur.

### Les données à embarquer

Le bloc « Données à embarquer », en bas du formulaire, choisit le sous-ensemble
extrait. Quatre critères, repris de `extract_ipe_subset.py` avec le n° de plan
d'eau et le nom de bassin en plus :

| Critère | Source de la valeur | Envoyé comme |
|---|---|---|
| **Région** | La région administrative saisie plus haut. | `{"mode": "region", "valeur": "02"}` |
| **N° de plan d'eau** | Le n° LCE saisi plus haut. | `{"mode": "lce", "valeur": "12777"}` |
| **Nom du bassin** | Un champ propre au bloc : le bassin n'appartient pas à l'identité de l'unité créée. | `{"mode": "bassin", "valeur": "Saguenay"}` |
| **Emprise personnalisée** | Un polygone tracé sur la carte, voir plus bas. | `{"mode": "emprise", "wkt": "POLYGON((…))", "bbox": […]}` |

Les critères se cochent **indépendamment** (`ChoixCriteres`) et partent dans un
tableau `criteres`. Le serveur les croise : une unité doit les satisfaire tous
pour être embarquée.

Le WKT est produit en **EPSG:4326** et non dans le CRS des données : c'est le
format attendu par le champ `extent` du seed QFieldCloud, et cela laisse au
serveur le soin de reprojeter vers le CRS de la base.

**Le n° de plan d'eau reste coché par défaut**, et c'est délibéré : douze des
dix-huit régions portent plus de 2 000 unités — jusqu'à 57 676 pour la région
01, 12 561 pour la 02 — et le serveur refuse au-delà de ce plafond, un
GeoPackage de cette taille n'étant pas téléchargeable sur le terrain. C'est
précisément ce que le croisement débloque : « Région » seule échoue sur les
grandes régions, mais « Région **et** bassin » ou « Région **et** emprise »
ramène la sélection à ce qu'un appareil de terrain télécharge. Le plafond se
règle par `IFA_FORMULAIRE_UNITES_MAX` côté serveur, sans redéploiement du
plugin.

La phrase sous les pastilles dit ce qui partira, ou nomme ce qui manque : un
critère coché dont le champ est vide laisse le bouton « Créer » éteint, et rien
d'autre à l'écran ne le dirait.

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

Deux points de `main.qml` rendent ce va-et-vient possible :

- le `Loader` ne libère une fenêtre qu'au chargement de la **suivante**, jamais à
  sa fermeture — sinon `close()` détruirait le formulaire et toute la saisie ;
- `ouvrirCommande()` **ferme le menu** avant de charger la fenêtre. Le menu est
  modal : le laisser ouvert en arrière-plan laisserait son voile intercepter les
  gestes, et la fenêtre qui se referme pour libérer la carte retomberait sur le
  menu au lieu de la carte.

Le menu n'est pas rouvert à la fermeture d'une commande : « Créer une UE »
enchaîne sur le formulaire de saisie de QField, que le menu masquerait. Le bouton
de la barre d'outils reste disponible pour y revenir.

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

### Les variables partent avec la demande

La fenêtre posait autrefois `code_region`, `code_projet`, `code_formulaire`,
`type_formulaire`, `code_lce` et `une_code_ident` sur le projet ouvert, d'où les
valeurs par défaut du formulaire QGIS les lisent. Ce n'est plus lui qui recevra
la saisie : elles voyagent donc dans le corps de la requête (`variables`), et le
serveur les inscrit dans le `.qgs` livré.

### Ouverture automatique — `PasseurProjet`

Une fois le packaging terminé, le projet est remis à `PasseurProjet`, qui le
télécharge et l'**ouvre à la place du projet courant**. « Consulter une UE »
s'en sert aussi (§7) : c'est le même composant, instancié **une seule fois dans
`main.qml`** et injecté dans les fenêtres (`fenetre.passeur`).

Il applique la recette que QField suit lui-même pour un projet qu'il vient de
créer (`QfCloudScreen.qml`) :

```
cloudProjectsModel.appendProject(id, true)
      ↓  projectAppended(projectId, hasError, errorString)
cloudProjectsModel.projectPackageAndDownload(id)
      ↓  projectDownloaded(projectId, projectName, projectOwner, hasError, errorString)
Qt.callLater → iface.loadFile(projet.localPath, projet.name)
```

* **`appendProject` n'est pas facultatif.** `projectPackageAndDownload` ignore
  sans rien dire un projet absent du modèle, et un projet que le serveur vient
  de créer n'y est pas encore.
* **`cloudProjectsModel` et `cloudConnection` sont atteignables** par
  `iface.findItemByObjectName()` : QField leur pose un `objectName` dans
  `qgismobileapp.qml` (vérifié en v4.2.11 et en master), et la recherche porte
  sur n'importe quel `QObject`. Une version précédente de ce README affirmait
  le contraire : c'était faux. L'échec d'alors venait de noms de méthodes
  inventés (`downloadProject`, `projectDownload`) dans l'ancien
  `telecharger()`, aujourd'hui supprimé.
* **`loadFile()` est différé** par `Qt.callLater` : il démonte le projet
  courant, et l'appeler dans la pile du signal du modèle détruirait le contexte
  de l'émetteur pendant qu'il émet.
* **Le signal `warning` du modèle est écouté.** Certains refus (« Project
  busy. ») ne passent que par lui : sans cela, l'attente serait éternelle.
* **Chaque étape a sa borne** : 20 s pour l'ajout au modèle, 3 min pour le
  téléchargement.

Le passeur vit dans `main.qml` et non dans une fenêtre parce que `loadFile()`
remplace le projet : le plugin d'application survit, mais « Créer une UE » est
déjà refermée quand la réponse arrive.

#### Vérifié avant d'appeler le serveur

`PasseurProjet.verifier()` rend `""` si tout est en place, sinon la raison de
l'empêchement. Les fenêtres l'appellent **avant** de créer ou de verrouiller une
unité — une unité créée dont le projet ne pourrait pas remplacer le projet
courant laisserait le technicien à mi-chemin. Elle vérifie :

1. que le modèle et ses méthodes sont atteignables dans cette version de QField ;
2. que **QField lui-même** est connecté à QFieldCloud (`cloudConnection.hasToken`).
   Le jeton d'`ifa_menu` (§10) ne sert à rien ici : c'est le compte de QField
   qui télécharge ;
3. qu'**aucune modification n'attend d'être synchronisée** dans le projet ouvert
   (`ServiceValidation.deltasEnAttente`, §8). Remplacer le projet pourrait les
   perdre.

Le passeur **ne pousse pas** les modifications de lui-même : c'est un choix
délibéré. Le message demande au technicien de synchroniser d'abord, puis de
recommencer.

#### La fenêtre d'attente — `DialogueAttente`

Du clic jusqu'à l'ouverture du projet, une fenêtre **centrée et modale** montre
une roue, le titre de l'opération (« Création de l'unité 02-12777-IPE ») et
l'étape en cours :

> Création de l'unité… → Unité créée et verrouillée — packaging en cours… →
> Récupération du projet… → Téléchargement du projet… → Ouverture du projet…

La fenêtre du plugin l'ouvre (`attente.suivre(titre, message)`), le passeur la
poursuit (`suivre("", message)` garde le titre) et la referme. Elle vit dans
`main.qml` pour **survivre à la fenêtre qui l'a ouverte** : « Créer une UE » se
referme dès le packaging terminé, bien avant la fin du téléchargement.

Elle n'a **aucun bouton** : un geste de trop au milieu d'un changement de projet
ne doit pas la faire disparaître. Elle ne peut pas rester bloquée pour autant :
chaque étape suivie a sa borne de temps (sondage du packaging, ajout,
téléchargement).

#### Le repli — `DialogueProjetPret`

Si l'ouverture automatique échoue — QField déconnecté, téléchargement en échec,
packaging trop long —, la fenêtre d'attente se referme et `DialogueProjetPret`
**nomme le projet à ouvrir** depuis l'écran « Projets ». Il rappelle d'abord ce
qui est acquis (« L'unité 02-12777-IPE est créée et verrouillée à votre nom. »),
puis la raison de l'échec.

Un dialogue et non un toast : un toast s'efface au bout de quelques secondes,
précisément quand la carte réapparaît et que le regard est ailleurs — or le nom
du projet est la seule prise pour retrouver son travail. Le dialogue ne part
que sur « J'ai compris » ; le nom y est détaché du texte, dans son propre
cadre.

Il connaît deux états. Le plus souvent le paquet est **prêt** et attend dans la
liste. Quand l'attente du packaging a expiré côté plugin — `sondagesMax`
dépassé, le serveur travaille encore —, il le dit et invite à rafraîchir la
liste dans quelques minutes : `ServiceFormulaire` émet alors `attenteExpiree`,
et la fenêtre l'annonce par `passeur.annoncerOuvertureManuelle(nom, texte, false)`.
Promettre un projet absent de l'écran « Projets » enverrait le technicien
chercher pour rien.

Une seule instance, dans `main.qml`, alimentée par le signal
`ouvertureImpossible` du passeur.

### Ce que voit le technicien

1. Au clic, si QField n'est pas connecté ou si des modifications attendent
   d'être synchronisées, un message le dit et **rien n'est envoyé** : l'unité
   n'est pas créée.
2. Sinon, la fenêtre d'attente s'ouvre et suit toutes les étapes. « Créer une
   UE » se referme dès le packaging terminé, pour ne pas inviter à renvoyer le
   même identifiant — une seconde demande identique serait traitée comme une
   reprise, pas comme une nouvelle unité.
3. Le projet `formulaire_UE_IFA` s'ouvre, et une notification le confirme.

En cas d'échec **avant** la création de l'unité, la fenêtre reste ouverte **avec
la saisie intacte** : l'appui peut être rejoué une fois la cause levée. En cas
d'échec **après**, l'unité existe et le dialogue de repli nomme le projet.

## 7. Consulter une UE

La fenêtre enchaîne deux étapes.

**Étape 1 — filtre.** Cinq critères : région, n° de plan d'eau, nom de bassin,
zone personnalisée (le `SelecteurEmprise` du §6, réutilisé tel quel), et
fragment de code d'UE.

Ils se cochent **indépendamment les uns des autres** (`ChoixCriteres`) et se
**croisent** : une unité doit les satisfaire tous. Chaque critère coché resserre
donc la liste — c'est ce qui rend la région praticable comme point de départ,
puisque seule elle rend plus de douze mille unités. Le bouton « Rechercher »
reste éteint tant qu'un critère coché n'est pas renseigné : un critère vide ne
restreindrait rien, alors que le technicien le croirait posé.

Les critères « Code d'UE » et « Nom du bassin » sont des **recherches
partielles** : le serveur cherche la saisie n'importe où dans la colonne, sans
tenir compte de la casse. Un technicien qui tape `12777` obtient les unités de
ce plan d'eau tous types confondus, `ANRO` celles du réseau, `02-127` celles
dont le code commence ainsi. Pour le bassin, c'est la seule forme praticable :
`infor_gener.ing_nom_bassi` est un texte libre du fonds hérité, où « Saguenay »
et « SAGUENAY (BASSIN) » coexistent. Deux caractères au minimum dans les deux
cas — en deçà, le bouton « Rechercher » reste désactivé.

**Étape 2 — résultats.** Un rappel du filtre avec un bouton « Modifier », puis
la liste des unités. Les colonnes reprennent la table `unite_echan` :

| Colonne | Champ |
|---|---|
| Code UE | `une_code_ident` |
| Type d'UE | `tue_nom` (via `tue_code_ident`) |
| Verrou | `une_ind_verro` (`O`/`N`), et **le nom du détenteur écrit sous la pastille** (`une_nom_propr_verro`, « par vous » quand c'est le compte connecté) |
| Créée le / Créée par | `une_date_creat` / `une_code_utili_creat` |
| Modifiée le / Par | `une_date_maj` / `une_code_utili_maj` |
| Actions | ouvrir et verrouiller · ouvrir sans verrouiller · supprimer |

**Détenteur du verrou et auteur de la dernière mise à jour sont deux choses
distinctes.** Le détenteur (`une_nom_propr_verro`) est celui à qui s'adresser
*maintenant* pour obtenir l'unité ; l'auteur de la mise à jour
(`une_code_utili_maj`) est celui qui a écrit les dernières données. Une unité
rendue garde l'auteur de sa dernière saisie sans avoir de détenteur, et une
unité fraîchement verrouillée n'a pas encore été modifiée par celui qui la
tient. D'où deux colonnes, et non une.

Le nom du détenteur est **écrit**, pas mis en infobulle : une infobulle ne
s'atteint pas au doigt, et sur une tablette de terrain l'information n'existait
donc pas. L'infobulle de la pastille subsiste pour les noms trop longs pour la
colonne, qui y sont élidés.

Une unité déjà verrouillée voit « ouvrir et verrouiller » et « supprimer »
désactivés. La suppression passe obligatoirement par une confirmation qui nomme
l'unité.

`TableauUE` bascule en fiches empilées sous 640 px de large — la fiche porte la
même information, le détenteur sur sa propre ligne. Un tableau de huit colonnes
n'est pas seulement illisible sur un téléphone : atteindre la corbeille
demanderait un défilement horizontal, geste propice aux suppressions
accidentelles.

### D'où viennent les résultats

`ServiceUE.qml` interroge le point d'accès QFieldCloud

```
POST /api/v1/ifa/unites/recherche/
```

servi par l'application Django `qfieldcloud.ifa` (dossier
`QfieldCloud-ifa/docker-app/qfieldcloud/ifa/`). Celle-ci lit la base métier du
ministère — schéma `ifa_data`, **en lecture seule** — de sorte que QField n'a
jamais d'accès direct à PostgreSQL.

Corps de la requête — les critères cochés, croisés par le serveur :

```json
{
  "criteres": [
    { "mode": "region",  "valeur": "02" },
    { "mode": "bassin",  "valeur": "Saguenay" }
  ],
  "limite": 200,
  "decalage": 0
}
```

Les modes disponibles :

```json
{ "mode": "region",  "valeur": "02" }
{ "mode": "lce",     "valeur": "12777" }
{ "mode": "bassin",  "valeur": "Saguenay" }     // fragment, casse indifférente
{ "mode": "code",    "valeur": "12777" }        // fragment, casse indifférente
{ "mode": "emprise", "wkt": "POLYGON((…))", "bbox": [xmin, ymin, xmax, ymax] }
```

Un même mode ne peut figurer qu'une fois : deux régions croisées par `AND` ne
rendraient jamais rien.

Réponse :

```json
{ "mode": "region",
  "criteres": [ { "mode": "region", "valeur": "02" },
                { "mode": "bassin", "valeur": "Saguenay" } ],
  "filtre": "région 02 et bassin « Saguenay »",
  "total": 12561, "limite": 200, "decalage": 0,
  "tronque": true, "resultats": [ … ] }
```

`mode` n'y reprend que le premier critère : il est conservé pour les plugins
antérieurs, qui envoient encore `mode` et `valeur` à plat et que le serveur
continue d'accepter.

Trois points valent d'être connus côté serveur :

- **la région ne se lit pas dans le code d'UE.** Le préfixe (`02-…`) s'en
  approche mais ment : plus de 5 000 unités portent un préfixe différent de la
  région de leur projet. La source qui fait foi est `proje_sonda.rad_no`,
  atteinte par les mesurages de l'unité.
- **la zone personnalisée s'appuie sur `infor_gener.shape`** (EPSG:32187). Le
  polygone du filtre est reprojeté vers ce SRID plutôt que l'inverse :
  transformer 638 000 points à chaque recherche condamnerait l'index GiST.
- **le nom de bassin vit dans `infor_gener.ing_nom_bassi`**, un texte libre
  saisi au fil des années sans référentiel fermé. D'où la recherche par
  fragment, insensible à la casse : exiger la graphie exacte ne servirait qu'à
  ceux qui savent déjà ce que la base contient. Le nom accompagne désormais
  chaque ligne de résultat (`ing_nom_bassi`).

### Pagination

`unite_echan` compte environ 142 000 lignes et une recherche par région en
renvoie plus de 12 000 : le serveur ne rend qu'une page (200 unités par
défaut). La fenêtre affiche le décompte complet et un bouton « Afficher les
suivantes » ; `ServiceUE` cumule les pages et rend au signal `resultats` la
liste entière, de sorte que ni `FenetreConsulterUE` ni `TableauUE` n'ont à
recoller quoi que ce soit.

### Authentification

`SessionCloud.qml` s'occupe du jeton — voir §10.

### Ouvrir une unité

Les deux boutons d'ouverture passent par `ServiceOuverture.qml`, qui interroge
`POST /api/v1/ifa/unites/<code>/ouvrir/`. Le serveur y recopie le projet modèle
sous le compte de l'utilisateur et remplit son GeoPackage des seuls inventaires
de l'unité demandée.

**« Ouvrir et verrouiller ».** `DialogueRaisonVerrou` demande d'abord le motif —
il est obligatoire, puisque c'est ce que liront les autres équipes en tentant
d'ouvrir la même unité. Le serveur verrouille alors l'unité dans la base
(`une_ind_verro`, `une_nom_propr_verro`, `une_date_verro`, `une_raiso_verro`,
plus `une_date_maj` et `une_code_utili_maj`), puis prépare le projet
`affichage_UE_IFA_RW`, modifiable.

**« Ouvrir sans verrouiller ».** Aucune écriture dans la base : ni verrou, ni
date de mise à jour. Le projet `affichage_UE_IFA_R` est livré avec toutes ses
couches en lecture seule — l'unité reste disponible pour les autres équipes.

Un projet d'affichage par utilisateur et par mode, réutilisé d'une unité à la
suivante : l'appareil garde ses réglages et son cache de fonds de carte. En
contrepartie, ouvrir une autre unité **remplace** le contenu du projet ; le
serveur refuse de le faire tant que des modifications n'ont pas été
synchronisées. Le plugin le vérifie de son côté **avant même d'appeler le
serveur** (`PasseurProjet.verifier()`, §6) : QField doit être connecté à
QFieldCloud, et aucune modification ne doit attendre d'être synchronisée. Sinon
un message le dit, et l'unité n'est pas verrouillée.

L'ouverture se déroule en quatre temps : verrouillage, remplissage (la réponse
donne le nombre d'enregistrements écrits), attente du packaging — un travail
QGIS que le service suit par `GET /api/v1/jobs/<id>/` —, puis téléchargement et
ouverture du projet **à la place du projet courant**, par `PasseurProjet` (§6).
Le même passeur sert les deux modes ; en cas d'échec, le dialogue de repli
rappelle ce qui est acquis (« L'unité … est verrouillée à votre nom. ») et nomme
le projet à ouvrir depuis l'écran « Projets ».

```
PasseurProjet.verifier()                     FenetreConsulterUE (avant tout appel)
POST /api/v1/ifa/unites/<code>/ouvrir/       ServiceOuverture
GET  /api/v1/jobs/<id>/  (sondage)           ServiceOuverture
téléchargement · ouverture                   PasseurProjet
```

L'ensemble prend de quelques secondes à quelques minutes, et l'attente se
signale à plusieurs endroits — un seul ne suffisait pas :

* la **fenêtre d'attente centrée** (`DialogueAttente`, §6) suit toutes les
  étapes, du verrouillage à l'ouverture du projet ;
* un **toast** part dès le clic en consultation, avant même la réponse du
  serveur ;
* la **ligne du tableau** remplace ses actions par une roue et « Ouverture… »,
  les autres lignes se désactivant (`TableauUE.uniteEnCours`) — jusqu'à la fin
  du téléchargement, pas seulement du packaging ;
* un **bandeau** épinglé sous l'en-tête donne l'étape en cours
  (`IfaPopup.activite`), repris du passeur une fois le packaging terminé.

Le bandeau est volontairement **hors de la zone défilante**. Posé dans le flux,
au-dessus du tableau, il sortait de l'écran dès que le technicien descendait la
liste pour cliquer — c'est-à-dire exactement quand il servait.

Une fois le projet ouvert, la fenêtre « Consulter une UE » se referme : elle
recouvrirait le projet qu'elle vient d'ouvrir.

### Rendre une unité

Le premier bouton de la ligne est **le même bouton dans les deux sens**. Sur une
unité libre, c'est un cadenas fermé : « ouvrir et verrouiller ». Sur une unité
que l'utilisateur tient lui-même, il devient un cadenas **ouvert**, en orange :
« déverrouiller ». Sur une unité tenue par quelqu'un d'autre, il reste fermé et
éteint, l'infobulle nommant le détenteur.

Un bouton plutôt que deux : les trois cas s'excluent, et une colonne d'actions
qui s'allonge sur un écran de terrain est une colonne où l'on se trompe de
cible. La fiche compacte, elle, écrit le verbe en toutes lettres — sur un
téléphone, un cadenas seul ne dit pas s'il ferme ou s'il ouvre.

**Qui a le droit.** `TableauUE.estMoi()` compare `une_nom_propr_verro` au compte
connecté (`SessionCloud.utilisateur`), exactement et tronqué à 100 caractères —
mot pour mot la condition du `UPDATE` que le serveur exécutera. Un rapprochement
plus indulgent, insensible à la casse par exemple, afficherait un bouton que le
serveur refuserait ensuite. Sans session, `utilisateur` vaut `""` et le
déverrouillage n'est jamais proposé : le bon repli, puisque le serveur ne laisse
lever un verrou que par son détenteur.

La liste peut néanmoins avoir vieilli — un collègue a pu reprendre l'unité
depuis la recherche. C'est le serveur qui tranche, et son refus nomme le nouveau
détenteur.

**Une confirmation.** Rendre une unité n'est pas rattrapable d'un clic : une
autre équipe peut la prendre dans la minute, et il faudra alors attendre qu'elle
la rende. Le dialogue nomme l'unité — le tableau est dense et les lignes se
ressemblent — et rappelle de synchroniser avant.

L'appel est `POST /api/v1/ifa/unites/<code>/deverrouiller/`, porté par
`ServiceVerrou.qml`. Sa réponse donne l'état de verrou tel que la base le porte
ensuite : `FenetreConsulterUE.appliquerVerrou()` s'en sert pour remettre la
ligne à jour **sans relancer la recherche**. Une unité qui n'était déjà plus
verrouillée n'est pas une erreur — le résultat voulu est là — mais le dire évite
au technicien de croire que son geste a porté.

Pendant l'aller-retour, la ligne remplace ses actions par une roue et
« Déverrouillage… », et les autres lignes se désactivent : même traitement que
l'ouverture (`TableauUE.uniteDeverrouillage`, et `occupe` qui réunit les deux).

### Ce qui reste à faire

**La suppression** est encore une simple notification : `DELETE
/api/v1/ifa/unites/<code>/` n'existe pas côté serveur.

**Le retour des modifications vers la base** n'existe pas non plus : le projet
d'affichage n'est pas relié à PostgreSQL, ce qui est saisi sur le terrain reste
dans son GeoPackage.

**La liste des projets déjà sur l'appareil** — sous le formulaire de recherche,
avec un bouton pour ouvrir directement — a été écrite puis **retirée**, le temps
de reprendre le sujet à tête reposée. Ce qu'elle a laissé derrière elle reste
acquis : `ExplorateurProjets.qml`, dont l'en-tête dit où QField range ses
projets et pourquoi `platformUtilities.appDataDirs()` ne l'indique pas.

---

## 8. Validation des données

Le serveur valide les données à chaque synchronisation et dépose son verdict
dans le paquet du projet, sous `rapport_ife.json`. C'était l'objet du plugin
autonome `plugin_event.qml` ; il vit désormais ici, et partage la session du
reste du programme — **un seul jeton, une seule demande de mot de passe**, là où
deux plugins se les disputaient (voir §10).

| Élément | Rôle |
|---|---|
| `ServiceValidation.qml` | Guette les synchronisations, va chercher le rapport. Vit dans `main.qml`. |
| `FenetreValidation.qml` | Affiche le verdict, les compteurs et les anomalies. |
| `DialogueDeverrouillage.qml` | Après un push : rendre l'unité, ou la garder. |

Deux points d'entrée : la commande **Validation → Rapport de validation** du
menu, et un **second bouton dans la barre d'outils** dont la couleur donne
l'état sans rien ouvrir — vert (données conformes), rouge (anomalies
bloquantes), gris (l'affichage n'engage rien).

### L'événement, c'est un fichier local

Aucune horloge n'interroge le serveur. L'état ne peut changer qu'à l'ouverture
du projet, au push, ou sur rafraîchissement manuel — et une requête n'est émise
qu'à ces moments-là. Au repos, le plugin ne parle pas au serveur.

La seule horloge qui tourne lit `deltafile.json`, que QField écrit à chaque
saisie et **vide** quand le serveur a accepté le push. Ni connexion ni poignée
de main TLS : c'est cette lecture, toutes les 400 ms, qui sert d'événement.

Le serveur ne rappelle jamais le plugin, et la validation se déroule *après* la
réponse HTTP du push : une requête unique arriverait trop tôt. Le service tire
donc quelques tentatives espacées (2, 4, 8, 15 puis 30 secondes), arrêtées dès
que le rapport reçu est plus récent que celui affiché — c'est `genere_le` qui en
décide, pas un délai. La fenêtre épuisée, l'état passe à « périmé » : le verdict
est grisé et le bandeau invite à rafraîchir. **Un rapport qui ne reflète plus
les données est plus dangereux qu'une absence de rapport**, puisqu'il rassure
sur un état dépassé.

Une exception au « une requête à chaque événement » : **au démarrage, rien ne
part si la session n'a ni jeton ni mot de passe en mémoire**. Réclamer un mot de
passe à l'ouverture de QField, pour un rapport que personne n'a demandé, serait
déplacé ; la fenêtre affiche alors « Rapport non chargé » et son bouton
« Rafraîchir » le va-chercher. Après un push, en revanche, la demande est
attendue — c'est le technicien qui vient d'agir.

> L'ancien plugin autonome `formulaires/plugins/plugin_event.qml` fait
> double emploi avec tout ceci. Le laisser installé à côté ferait deux boutons
> dans la barre d'outils, deux sondages du même fichier, et deux jetons qui
> s'expirent mutuellement (voir §10) : il est à désactiver.

### Ce que montre l'interface pendant l'attente

Le serveur peut mettre trente secondes à produire son rapport. Rien ne doit
laisser croire, pendant ce temps, que le plugin est figé — trois endroits le
disent donc ensemble :

| Où | Quoi |
|---|---|
| Bouton de la barre d'outils | Il **clignote** entre gris et couleur d'accent, avec l'étape en infobulle. |
| Fenêtre « Rapport de validation » | Le bandeau épinglé d'`IfaPopup` — roue qui tourne et texte d'étape. Le bouton devient « Interrogation… ». |
| Notifications | « Modifications synchronisées — validation en cours… », puis le verdict à l'arrivée. |

Les notifications ne sont pas un luxe : après un push, la fenêtre de validation
n'est pas ouverte, et le bandeau ne se voit donc pas. Le verdict n'est annoncé
que pour le rapport **qu'on guettait** ; en annoncer un à chaque ouverture de
projet ou à chaque « Rafraîchir » serait du bruit.

> **Le clignotement vient d'une minuterie, pas d'une animation.** Une
> `SequentialAnimation on opacity` posée sur le `QfToolButton` n'a rien donné à
> l'écran : ce composant appartient à QField, et ce qu'il fait de son `opacity`
> ne nous appartient pas — l'animation a échoué en silence. Une minuterie qui
> bascule un booléen lié à `bgcolor` ne peut, elle, que repeindre.
>
> **Une attente trop courte ne se voit pas.** Contre le serveur local, une
> requête revient en quelques dizaines de millisecondes : l'indication
> apparaissait et disparaissait dans le même souffle. `attenteVisible` la
> maintient 1,2 s de plus — du confort d'affichage, dont rien ne dépend.
>
> **Deux états, et non un seul.** « On attend le serveur »
> (`enAttenteServeur`) et « l'affichage n'engage rien » (`enAttente`) ne se
> recouvrent pas : pendant un simple rafraîchissement, le rapport déjà à
> l'écran reste valable. Les avoir confondus grisait le verdict et faisait
> clignoter « aucun rapport chargé » à chaque appui — et, à l'inverse, une
> requête en vol ne levant aucun des deux, un « Rafraîchir » ne montrait
> **rien** entre l'appui et la réponse.

### Le push demande d'abord si l'unité doit être rendue

> Ce dialogue et le bouton du tableau (§7) aboutissent au même point d'accès, et
> c'est `ServiceVerrou.qml` qui le porte pour les deux : la requête n'est écrite
> qu'une fois. Ce qui diffère, c'est le moment et ce que chacun en fait — ici la
> question suit une synchronisation et enchaîne sur le rapport de validation ;
> là-bas, c'est un geste isolé qui remet une ligne à jour.

Le verrou posé à l'ouverture (ou à la création) retire l'unité aux autres
équipes jusqu'à ce que quelqu'un la relâche. Une synchronisation est le moment
naturel de poser la question : la saisie est partie, le technicien en a
peut-être fini.

```
deltafile vidé  →  « Déverrouiller l'unité 02-12777-IPE ? »
                        ├─ Déverrouiller      → POST …/deverrouiller/
                        └─ Garder verrouillée
                   puis, dans les deux cas : attente du rapport
```

L'ordre n'est pas indifférent. La question part **avant toute requête**, donc
avant que la session ne réclame le mot de passe : lancer les deux ensemble
ferait surgir la demande de mot de passe par-dessus le dialogue, et le
technicien répondrait à deux questions superposées.

Quelle unité ? Le nom du projet ne le dit pas — il est le même d'une unité à la
suivante. C'est la **variable de projet `une_code_ident`**, que le serveur
inscrit dans le `.qgs` livré, que le service lit. Un projet qui ne la porte pas
(un projet qui n'a pas été préparé par les points d'accès IFA) ne déclenche
aucune question : il n'y a rien à déverrouiller.

Le déverrouillage est réservé au détenteur du verrou. Une unité tenue par
quelqu'un d'autre ressort en `409`, et le message le nomme ; une unité qui
n'était pas verrouillée n'est pas une erreur. Voir le §6 du README de
`qfieldcloud.ifa`.

L'échec du déverrouillage **n'interrompt pas** la suite : le rapport de
validation s'obtient indépendamment. Le technicien en est averti — sans quoi il
croirait avoir rendu son unité.

---

## 9. Bon à savoir

**Recharger après modification.** QField ne contourne le cache QML que pour le
fichier principal du plugin. Les composants voisins (`MenuPrincipal.qml`,
`IfaPopup.qml`, …) sont chargés normalement : après les avoir modifiés,
**relancer QField**. Désactiver/réactiver le plugin ne suffit pas toujours.

**Un Popup créé au chargement du plugin n'a pas encore de fenêtre où
s'afficher.** Un plugin d'application est chargé très tôt : `iface.mainWindow()`
rend alors `null` — c'est la raison du réessai du bouton de barre d'outils dans
`main.qml`. Un `parent: iface.mainWindow().contentItem` évalué à la
construction reste donc nul **pour toujours** : `iface.mainWindow()` n'est pas
une propriété, la liaison ne se réévalue jamais. `open()` ne montre alors rien,
sans la moindre erreur — c'est exactement ce qui est arrivé à
`DialogueDeverrouillage`. Résoudre la zone parente **juste avant** d'ouvrir,
comme le font `IfaPopup.onAboutToShow`,
`DialogueDeverrouillage.resoudreZoneParente()`, `DialogueAttente.suivre()` et
le repli du passeur dans `main.qml`.

**Autorisation.** QField demande une autorisation au premier chargement d'un
plugin. Elle est mémorisée par chemin d'installation : réinstaller ailleurs la
redemande.

**API non documentée.** `iface.findItemByObjectName()` sert à atteindre
`dashBoard`, `overlayFeatureFormDrawer`, `positionSource` et, pour
`PasseurProjet`, `cloudProjectsModel` et `cloudConnection`. Ces noms ne font pas
partie de l'API publique des plugins : une mise à jour de QField peut les
renommer. Tous les appels sont donc gardés et signalent un message clair plutôt
que de planter — le passeur vérifie aussi que chaque méthode appelée existe
(`typeof … === "function"`). Noms vérifiés sur QField `f7123fc` (v4.2.11,
31 juillet 2026). La recherche porte sur n'importe quel `QObject`, pas
seulement les éléments visuels : un modèle se trouve aussi.

**Pas d'énumérations QField dans le QML du plugin.** Les classes du cloud
(`QFieldCloudProject.ProjectStatus`, …) ne sont pas garanties visibles d'un
plugin. Le passeur s'en passe : il ne lit que des signaux, des booléens
(`hasToken`) et des chaînes (`localPath`).

**Un GeoPackage tronqué après une ouverture automatique.** Observé une fois
(29 septembre 2026) : après « Créer une UE », `data.gpkg` arrivait coupé
(643 Ko sur les 11 Mo annoncés par son en-tête), réécrit sur le disque trois
secondes **après** un téléchargement complet — le serveur l'avait servi entier,
sa copie était intacte. Non reproduit depuis, cause inconnue. Si cela revient :
**ne toucher à aucun fichier**, et comparer tout de suite la taille du fichier,
sa date, la taille annoncée par son en-tête (octets 28–31 × taille de page) et
les journaux `nginx` du serveur. Supprimer la copie locale du projet puis le
retélécharger depuis « Projets » répare.

**Couleurs.** Les accents sont désignés par le **nom** d'une couleur du thème
(`"mainColor"`, `"cloudColor"`), pas par une valeur `#rrggbb` : le rendu suit
ainsi le thème clair comme le thème sombre. `IfaPopup.surAccent` calcule
automatiquement une couleur de texte lisible sur l'accent choisi.

**Cible tactile.** Les lignes de commande font au moins 64 px de haut, pour
rester utilisables avec des gants.

---

## 10. SessionCloud — parler au serveur

`SessionCloud.qml` porte l'URL du serveur, le jeton, et une seule fonction
utile :

```js
session.appeler("POST", "/api/v1/ifa/unites/recherche/", corps,
                function (donnees) { … },        // succès, réponse décodée
                function (message) { … });       // échec, message affichable
```

Une instance unique est créée dans `main.qml` et injectée dans chaque fenêtre
sous le nom `session`, comme `referentiels`.

**Rien n'est codé en dur.** L'URL et le nom d'utilisateur viennent de l'objet
`QFieldCloudConnection` de QField, atteint par son `objectName`. Le même plugin
fonctionne donc sur l'instance locale, sur le VPS ou sur une adresse de réseau
local, sans être ré-édité.

**Le jeton de QField n'est pas empruntable.** `token()`, `get()` et `post()` de
`QFieldCloudConnection` sont de simples fonctions C++ — ni `Q_PROPERTY` ni
`Q_INVOKABLE` — donc invisibles depuis QML. Le plugin obtient son propre jeton
par `POST /api/v1/auth/login/`, en demandant le mot de passe si QField ne le
détient pas. Le mot de passe ne vit que le temps de l'appel : il n'est ni
conservé ni journalisé.

**Le jeton peut être révoqué sous nos pieds.** Côté serveur,
`AuthToken.single_token_clients` fait expirer les jetons antérieurs du même
utilisateur **et du même type de client**. Les requêtes QML partent avec le
`User-Agent` par défaut de Qt (`Mozilla/5.0`), que le serveur classe en
`unknown` : deux plugins IFA sur le même appareil se disputeraient donc le
jeton. D'où la reprise automatique sur `401` — le jeton est jeté, une nouvelle
authentification est demandée, la requête est rejouée **une** fois.

> **À corriger dans les notes plus anciennes :** on lit parfois qu'il faudrait
> envoyer un `User-Agent` du type `sdk|ifa-plugin/1.0` pour éviter d'expirer le
> jeton de QField. C'est impossible et inutile. Impossible : Qt refuse cet
> en-tête dans `XMLHttpRequest` (liste noire de `QQmlXMLHttpRequest`) et
> `setRequestHeader` l'ignore silencieusement. Inutile : le jeton de QField est
> de type `qfield`, et `single_token_clients` ne fait expirer que les jetons
> **du même type** — un jeton `unknown` ne peut pas le toucher. Vérifié dans la
> table `authentication_authtoken` du serveur local.

**Une minuterie par requête.** Plusieurs recherches peuvent être en vol en même
temps ; un `Timer` unique les mélangerait. Au-delà de 30 secondes, l'appel rend
un message plutôt qu'un sablier éternel.
