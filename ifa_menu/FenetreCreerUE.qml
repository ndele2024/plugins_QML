// =============================================================================
//  FenetreCreerUE — création d'une unité d'échantillonnage
// =============================================================================
//  Reprend le formulaire du plugin projet
//  « v7_default_config_pkey_ObvervationGenTest_cloud_qfield.qml » :
//
//    région administrative → projet → type d'UE → n° de plan d'eau (LCE)
//    → identifiant UE (composé automatiquement, modifiable à la main)
//
//  ---------------------------------------------------------------------------
//  CE QUE FAIT « CRÉER »
//  ---------------------------------------------------------------------------
//  La saisie ne se fait plus dans le projet ouvert, mais dans un projet dédié
//  que le serveur prépare : `formulaire_UE_IFA`, sous le compte de
//  l'utilisateur. Un appui sur « Créer » enchaîne donc, par
//  `ServiceFormulaire` :
//
//    1. l'unité est **inscrite dans `ifa_data.unite_echan` et verrouillée** au
//       nom de l'utilisateur, raison « nouvelle Unité d'échantillonnage » :
//       son code est réservé avant que quiconque parte sur le terrain ;
//    2. le serveur retrouve — ou crée à partir du projet modèle — le projet
//       `formulaire_UE_IFA` de l'utilisateur ;
//    3. il remplit son GeoPackage des données choisies dans « Données à
//       embarquer », lues dans le schéma `ifa_data`, la nouvelle unité
//       comprise ;
//    4. `PasseurProjet` télécharge le projet et l'ouvre à la place du projet
//       courant ; s'il n'y parvient pas, un dialogue nomme le projet à ouvrir
//       depuis l'écran « Projets ».
//
//  Une fenêtre d'attente centrée (DialogueAttente, dans main.qml) suit tout
//  le parcours, y compris après la fermeture de cette fenêtre.
//
//  Les valeurs saisies ici ne sont donc plus posées sur le projet ouvert : ce
//  n'est pas lui qui recevra la saisie. Elles partent avec la demande et le
//  serveur les inscrit comme **variables du projet livré**, où elles
//  alimentent les valeurs par défaut du formulaire QGIS.
//
//  Différences avec le plugin d'origine :
//    * tous les accès aux couches passent par Referentiels et sont défensifs :
//      une couche absente affiche un message, elle ne casse plus le plugin ;
//    * les itérateurs sont refermés sur tous les chemins d'exécution ;
//    * le bouton « Créer » reste désactivé tant que la saisie est incomplète.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

IfaPopup {
  id: fenetre

  titre: qsTr("Créer une UE")
  soustitre: qsTr("Nouvelle unité d'échantillonnage")
  icone: "ic_add_white_24dp"
  accent: Theme.cloudColor

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  // Dès que l'utilisateur modifie l'identifiant à la main, on cesse de le
  // recomposer automatiquement.
  property bool identifiantModifie: false

  // Dernier résultat de recherche LCE ({ coucheDisponible, trouve, nom, mrc }).
  property var resultatLce: null


  // ---- Filtre des données à embarquer ---------------------------------------
  // Détermine le sous-ensemble de données extrait dans les GeoPackage du projet
  // dérivé. Les modes reprennent ceux de `extract_ipe_subset.py`, avec le n° de
  // plan d'eau et le nom de bassin en plus.
  //
  // Les critères cochés se **croisent** : une unité doit les satisfaire tous
  // pour être embarquée. C'est ce qui rend la région utilisable. Douze des
  // dix-huit régions portent plus de 2 000 unités — jusqu'à 57 676 pour la
  // région 01 — et le serveur refuse alors la demande, un GeoPackage de cette
  // taille n'étant pas téléchargeable sur le terrain. Croisée avec un bassin ou
  // une emprise, la même région redevient embarquable.
  //
  // Le n° de plan d'eau reste coché par défaut : c'est le critère qui aboutit à
  // coup sûr, et c'est le geste courant — le n° LCE vient d'être saisi
  // au-dessus.
  readonly property var criteresDisponibles: [
    {
      cle: "region",
      libelle: qsTr("Région")
    },
    {
      cle: "lce",
      libelle: qsTr("N° de plan d'eau")
    },
    {
      cle: "bassin",
      libelle: qsTr("Nom du bassin")
    },
    {
      cle: "emprise",
      libelle: qsTr("Emprise personnalisée")
    }
  ]

  property var criteresActifs: ["lce"]

  // Emprise personnalisée, renseignée par SelecteurEmprise.
  property string empriseWkt: ""
  property var empriseBbox: null
  property int empriseNombreSommets: 0

  // Sommets en CRS carte, conservés pour pouvoir reprendre un tracé existant.
  property var empriseSommets: []

  // Tous les critères cochés doivent être renseignés : un critère coché mais
  // vide ne restreindrait rien, alors que le technicien croirait l'avoir posé.
  readonly property bool filtrePret: {
    if (criteresActifs.length === 0)
      return false;

    for (let i = 0; i < criteresActifs.length; ++i) {
      if (!critereRenseigne(criteresActifs[i]))
        return false;
    }

    return true;
  }

  readonly property bool saisieComplete: comboRegion.currentIndex >= 0 && comboType.currentIndex >= 0 && champIdentifiant.text.trim() !== "" && champIdentifiant.text.indexOf("[") === -1 && filtrePret

  // La session est facultative dans IfaPopup ; ici, elle est la condition de
  // tout ce que fait le bouton « Créer ».
  readonly property bool serveurJoignable: session !== null && session.disponible

  readonly property bool preparationEnCours: formulaire.enCours

  onOpened: {
    if (!referentiels)
      return;
    referentiels.chargerProjets();
    prepositionnerRegion();
    composerIdentifiant();
  }

  // ---------------------------------------------------------------------------
  //  Formulaire
  // ---------------------------------------------------------------------------
  //  Une colonne sur téléphone (libellé au-dessus du champ), deux colonnes dès
  //  qu'il y a la place (libellé à gauche, champ à droite).
  GridLayout {
    id: grille

    Layout.fillWidth: true

    columns: fenetre.compact ? 1 : 2
    columnSpacing: 16
    rowSpacing: fenetre.compact ? 4 : 10

    // ---- Avertissement : serveur injoignable ---------------------------------
    //  La saisie a lieu dans un projet que le serveur prépare : sans session
    //  QFieldCloud, « Créer » n'a rien à quoi s'adresser. Le formulaire reste
    //  affiché — le technicien peut se connecter puis revenir.
    Rectangle {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.preferredHeight: texteAvertissement.implicitHeight + 20
      Layout.bottomMargin: 6

      visible: !fenetre.serveurJoignable

      radius: 10
      color: Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.14)
      border.width: 1
      border.color: Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.4)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        IconImage {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          Layout.alignment: Qt.AlignTop
          Layout.topMargin: 10
          source: Theme.getThemeVectorIcon("ic_alert_black_24dp")
          color: Theme.warningColor
          sourceSize: Qt.size(40, 40)
        }

        Label {
          id: texteAvertissement
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: qsTr("Aucune connexion QFieldCloud active : le projet de saisie ne peut pas être préparé. Connectez-vous au serveur depuis QField.")
          font: Theme.tinyFont
          color: Theme.mainTextColor
          wrapMode: Text.WordWrap
        }
      }
    }

    // ---- Région administrative -----------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      text: qsTr("Région administrative")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ComboBox {
      id: comboRegion

      Layout.fillWidth: true

      textRole: "nom"
      valueRole: "code"
      currentIndex: -1
      model: fenetre.referentiels ? fenetre.referentiels.regions : []

      onCurrentValueChanged: fenetre.composerIdentifiant()
    }

    // ---- Projet de sondage -----------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      text: qsTr("Projet")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ComboBox {
      id: comboProjet

      Layout.fillWidth: true

      textRole: "pro_nom"
      valueRole: "pro_no"
      currentIndex: -1

      // Filtré par la région choisie ; tous les projets si aucune région.
      // La référence à `projetsCharges` fait recalculer la liste dès que
      // Referentiels a fini de lire la couche.
      model: {
        if (!fenetre.referentiels || !fenetre.referentiels.projetsCharges)
          return [];
        return fenetre.referentiels.projetsDeLaRegion(comboRegion.currentValue);
      }

      // Toujours repartir d'une sélection vide quand la liste change.
      onModelChanged: currentIndex = -1

      displayText: currentIndex === -1 ? qsTr("Aucun projet sélectionné") : currentText

      delegate: ItemDelegate {
        width: comboProjet.width
        text: "[" + modelData["pro_an"] + "]  " + modelData["pro_no"] + " : " + modelData["pro_nom"]
        font: Theme.tipFont

        hoverEnabled: true
        ToolTip.visible: hovered
        ToolTip.text: text
        ToolTip.delay: 400
      }
    }

    // ---- Type d'unité d'échantillonnage ----------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      text: qsTr("Type d'UE")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ComboBox {
      id: comboType

      Layout.fillWidth: true

      textRole: "nom"
      valueRole: "code"
      currentIndex: -1
      model: fenetre.referentiels ? fenetre.referentiels.typesUe : []

      onCurrentValueChanged: fenetre.composerIdentifiant()

      delegate: ItemDelegate {
        width: comboType.width
        text: modelData["code"] + " : " + modelData["nom"]
        font: Theme.tipFont
      }
    }

    // ---- Numéro officiel du plan d'eau (LCE) -----------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      text: qsTr("N° du plan d'eau (LCE)")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      TextField {
        id: champLce

        Layout.fillWidth: true

        maximumLength: 8
        placeholderText: qsTr("ex. 12777")
        inputMethodHints: Qt.ImhDigitsOnly
        validator: IntValidator {}

        onTextChanged: {
          fenetre.resultatLce = null;
          fenetre.composerIdentifiant();
        }
        onAccepted: fenetre.rechercherLce()
      }

      QfButton {
        Layout.preferredWidth: 46
        enabled: champLce.text !== ""
        bgcolor: Theme.mainBackgroundColor
        color: fenetre.accent
        icon.source: Theme.getThemeVectorIcon("ic_baseline_search_white")
        onClicked: fenetre.rechercherLce()
      }
    }

    // ---- Résultat de la recherche LCE ------------------------------------------
    Rectangle {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.preferredHeight: texteResultatLce.implicitHeight + 18

      visible: fenetre.resultatLce !== null

      radius: 10
      color: Theme.controlBackgroundAlternateColor
      border.width: 1
      border.color: Theme.controlBorderColor

      Label {
        id: texteResultatLce

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12

        font: Theme.tinyFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap

        text: {
          const r = fenetre.resultatLce;
          if (!r)
            return "";
          if (!r.coucheDisponible)
            return qsTr("Couche « LCE » absente du projet : vérification impossible.");
          if (!r.trouve)
            return qsTr("Aucun plan d'eau ne porte le n° %1.").arg(champLce.text);
          return qsTr("Nom : %1\nMRC : %2").arg(r.nom).arg(r.mrc);
        }
      }
    }

    // ---- Identifiant de l'UE ---------------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      text: qsTr("Identifiant UE")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      TextField {
        id: champIdentifiant

        Layout.fillWidth: true
        font: Theme.strongFont

        onTextEdited: fenetre.identifiantModifie = true
      }

      Label {
        Layout.fillWidth: true
        visible: !fenetre.identifiantModifie
        text: qsTr("Composé automatiquement : région – n° LCE – type d'UE. Modifiable.")
        font: Theme.tinyFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }
    }

    // =========================================================================
    //  Données à embarquer
    // =========================================================================
    Rectangle {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.topMargin: 14
      Layout.preferredHeight: 1
      color: Theme.controlBorderColor
    }

    Label {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      text: qsTr("Données à embarquer")
      font: Theme.strongTipFont
      color: fenetre.accent
    }

    // ---- Choix du critère de filtrage ------------------------------------------
    Label {
      Layout.fillWidth: fenetre.compact
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: fenetre.compact ? 0 : 8
      text: qsTr("Filtrer sur")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ChoixCriteres {
      id: choixFiltre

      Layout.fillWidth: true
      // Un `Flow` calcule sa hauteur d'après sa largeur : sans l'annoncer au
      // GridLayout, les pastilles repliées sur un second rang seraient
      // coupées.
      Layout.preferredHeight: choixFiltre.implicitHeight
      Layout.minimumHeight: choixFiltre.implicitHeight

      accent: fenetre.accent
      criteres: fenetre.criteresDisponibles
      selection: fenetre.criteresActifs

      onSelectionChangee: function (selection) {
        fenetre.criteresActifs = selection;
      }
    }

    // ---- Ce que les critères retenus embarquent --------------------------------
    //  La phrase dit ce qui partira dans le GeoPackage, et nomme ce qui manque
    //  encore : un critère coché dont le champ est vide laisse le bouton
    //  « Créer » éteint, et rien à l'écran ne le dirait autrement.
    Label {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true

      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap

      text: fenetre.explicationFiltre()
    }

    // ---- Nom du bassin -----------------------------------------------------------
    //  Contrairement à la région et au n° de plan d'eau, qui reprennent les
    //  champs de l'unité saisis plus haut, le bassin n'appartient pas à
    //  l'identité de l'unité créée : il ne sert qu'à choisir ce qu'on emporte.
    //  D'où un champ à lui, ici, dans le bloc auquel il appartient.
    Label {
      Layout.fillWidth: fenetre.compact
      visible: fenetre.estActif("bassin")
      text: qsTr("Nom du bassin")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    ColumnLayout {
      Layout.fillWidth: true
      visible: fenetre.estActif("bassin")
      spacing: 2

      TextField {
        id: champBassin

        Layout.fillWidth: true
        placeholderText: qsTr("ex. Saguenay, Outaouais…")
      }

      Label {
        Layout.fillWidth: true
        text: qsTr("Recherche partielle : tout fragment du nom convient, majuscules ou non. Deux caractères minimum.")
        font: Theme.tinyFont
        color: Theme.secondaryTextColor
        wrapMode: Text.WordWrap
      }
    }

    // ---- Emprise personnalisée -------------------------------------------------
    Rectangle {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.preferredHeight: blocEmprise.implicitHeight + 24

      visible: fenetre.estActif("emprise")

      radius: 12
      color: Theme.controlBackgroundAlternateColor
      border.width: 1
      border.color: fenetre.empriseWkt !== "" ? Qt.rgba(fenetre.accent.r, fenetre.accent.g, fenetre.accent.b, 0.5) : Theme.controlBorderColor

      ColumnLayout {
        id: blocEmprise

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          spacing: 10

          IconImage {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            source: Theme.getThemeVectorIcon(fenetre.empriseWkt !== "" ? "ic_check_white_24dp" : "ic_geometry_polygon_24dp")
            color: fenetre.empriseWkt !== "" ? Theme.goodColor : Theme.secondaryTextColor
            sourceSize: Qt.size(44, 44)
          }

          Label {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter

            font: Theme.tipFont
            color: Theme.mainTextColor
            wrapMode: Text.WordWrap

            text: fenetre.empriseWkt !== "" ? qsTr("Emprise définie — %n sommet(s)", "", fenetre.empriseNombreSommets) : qsTr("Aucune emprise définie")
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          QfButton {
            Layout.fillWidth: true
            text: fenetre.empriseWkt !== "" ? qsTr("Modifier sur la carte") : qsTr("Tracer sur la carte")
            bgcolor: fenetre.accent
            color: fenetre.surAccent
            onClicked: fenetre.tracerEmprise()
          }

          QfButton {
            visible: fenetre.empriseWkt !== ""
            text: qsTr("Effacer")
            bgcolor: "transparent"
            color: Theme.secondaryTextColor
            borderColor: Theme.controlBorderColor
            onClicked: fenetre.effacerEmprise()
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Tracé de l'emprise sur la carte
  // ---------------------------------------------------------------------------
  //  Le sélecteur se rattache lui-même au conteneur de la carte : il sort donc
  //  de cette fenêtre, qui doit se refermer le temps du tracé.
  SelecteurEmprise {
    id: selecteurEmprise

    accent: fenetre.accent

    onValide: function (wkt, bbox, nombreSommets) {
      fenetre.empriseWkt = wkt;
      fenetre.empriseBbox = bbox;
      fenetre.empriseNombreSommets = nombreSommets;
      fenetre.empriseSommets = selecteurEmprise.sommets;
      fenetre.open();
      fenetre.avertir(qsTr("Emprise enregistrée — %n sommet(s)", "", nombreSommets));
    }

    onAnnule: fenetre.open()

    // Si la fenêtre est détruite pendant un tracé (l'utilisateur peut rouvrir
    // le menu et lancer une autre commande), le calque doit repartir avec elle.
    Component.onDestruction: selecteurEmprise.reinitialiserAffichage()
  }

  // ---------------------------------------------------------------------------
  //  Actions
  // ---------------------------------------------------------------------------
  actions: [
    QfButton {
      text: qsTr("Annuler")
      bgcolor: "transparent"
      color: Theme.secondaryTextColor
      onClicked: {
        // La préparation en cours n'est pas interrompue côté serveur : le
        // projet restera disponible dans « Projets ». Seul le suivi s'arrête.
        formulaire.annuler();
        fenetre.close();
      }
    },
    QfButton {
      text: fenetre.preparationEnCours ? qsTr("Préparation…") : qsTr("Créer")
      enabled: fenetre.saisieComplete && fenetre.serveurJoignable && !fenetre.preparationEnCours
      bgcolor: fenetre.accent
      color: fenetre.surAccent
      onClicked: fenetre.creerUe()
    }
  ]

  // ===========================================================================
  //  Préparation du projet de saisie
  // ===========================================================================
  //  Création de l'unité et projet `formulaire_UE_IFA` sur le serveur, attente
  //  du packaging, puis nom du projet à ouvrir. Voir `ServiceFormulaire.qml`.
  ServiceFormulaire {
    id: formulaire

    session: fenetre.session
    passeur: fenetre.passeur

    // Le bandeau pour la fenêtre, la fenêtre d'attente centrée pour tout le
    // parcours : elle reste à l'écran quand cette fenêtre se referme, jusqu'à
    // l'ouverture du projet par le passeur.
    onProgression: function (message) {
      fenetre.activite = message;
      if (fenetre.attente)
        fenetre.attente.suivre(qsTr("Création de l'unité %1").arg(fenetre.codeUniteCreee()), message);
    }

    onPret: function (infos) {
      // L'unité est créée, le projet est packagé : la fenêtre a fini son
      // travail. Elle se referme pour ne pas inviter à renvoyer le même
      // identifiant ; la fenêtre d'attente, dans main.qml, suit le passeur
      // jusqu'à l'ouverture du projet.
      fenetre.activite = "";
      fenetre.close();
    }

    // Le packaging n'a pas fini dans le temps imparti : l'unité existe, le
    // projet arrivera plus tard sous son nom. Le dialogue de repli commun
    // (main.qml) le nomme ; il referme aussi la fenêtre d'attente.
    //
    // Le code de l'unité se lit sur le service, qui le tient depuis la
    // réponse du serveur : `pret` n'a pas été émis.
    onAttenteExpiree: function (nomProjet) {
      fenetre.activite = "";
      if (fenetre.passeur)
        fenetre.passeur.annoncerOuvertureManuelle(nomProjet, qsTr("L'unité %1 est créée et verrouillée à votre nom.").arg(fenetre.codeUniteCreee()), false);
      else if (fenetre.attente)
        fenetre.attente.terminer();
    }

    onEchec: function (message) {
      // La fenêtre est encore là : la saisie est intacte, l'appui peut être
      // rejoué une fois la cause levée.
      fenetre.activite = "";
      if (fenetre.attente)
        fenetre.attente.terminer();
      fenetre.avertir(message, "error");
    }
  }

  // ===========================================================================
  //  Fonctions
  // ===========================================================================

  // Recompose l'identifiant tant que l'utilisateur ne l'a pas édité lui-même.
  // Les segments manquants restent visibles entre crochets, ce qui montre d'un
  // coup d'œil ce qui reste à saisir.
  function composerIdentifiant() {
    if (identifiantModifie)
      return;

    const region = comboRegion.currentValue ? comboRegion.currentValue : "[région]";
    const lce = champLce.text !== "" ? champLce.text : "[LCE]";
    const type = comboType.currentValue ? comboType.currentValue : "[type]";

    champIdentifiant.text = region + "-" + lce + "-" + type;
  }

  // Présélectionne la région : variable de projet si elle existe, sinon
  // position GPS courante.
  function prepositionnerRegion() {
    let codeRegion = referentiels.variableProjet("code_region");

    if (codeRegion === null || codeRegion === undefined || codeRegion === "") {
      codeRegion = referentiels.regionParGps();
    }

    if (codeRegion) {
      comboRegion.currentIndex = comboRegion.indexOfValue("" + codeRegion);
    }
  }

  function rechercherLce() {
    if (!referentiels)
      return;
    resultatLce = referentiels.rechercherLce(champLce.text);
  }

  // Libère l'écran puis passe la main au sélecteur. La fenêtre n'est pas
  // détruite à la fermeture (voir le Loader de main.qml) : la saisie en cours
  // est donc intacte au retour.
  function tracerEmprise() {
    close();

    if (!selecteurEmprise.demarrer(empriseSommets)) {
      open();
      avertir(qsTr("La carte n'est pas accessible : tracé impossible."), "warning");
    }
  }

  function effacerEmprise() {
    empriseWkt = "";
    empriseBbox = null;
    empriseNombreSommets = 0;
    empriseSommets = [];
  }

  // Demande au serveur le projet de saisie, puis laisse le service enchaîner
  // sur le téléchargement et l'ouverture.
  //
  // Le passeur est consulté d'abord : une unité créée — donc verrouillée —
  // dont le projet ne pourrait pas remplacer le projet courant (modifications
  // non synchronisées, QField déconnecté) laisserait le technicien à mi-chemin.
  function creerUe() {
    const empechement = passeur ? passeur.verifier() : "";
    if (empechement !== "") {
      avertir(empechement, "warning");
      return;
    }

    formulaire.creer(uniteACreer(), filtreDonnees(), variablesProjet());
  }

  // Le code de l'unité tel que la base le porte, ou la saisie si le serveur
  // n'a pas encore répondu.
  function codeUniteCreee() {
    const unite = formulaire.uniteCreee;

    if (unite && unite["une_code_ident"])
      return "" + unite["une_code_ident"];

    return champIdentifiant.text.trim();
  }

  // L'unité que le serveur inscrira dans `unite_echan`. Le type voyage par son
  // libellé : c'est ce que porte la liste des types du plugin, et le serveur le
  // résout en `tue_code_ident` dans le référentiel.
  function uniteACreer() {
    return {
      "une_code_ident": champIdentifiant.text.trim(),
      "type_ue": comboType.currentText
    };
  }

  function estActif(mode) {
    return criteresActifs.indexOf(mode) !== -1;
  }

  // Un critère coché est-il utilisable ? Les bornes reprennent celles du
  // serveur.
  function critereRenseigne(mode) {
    if (mode === "region")
      return comboRegion.currentIndex >= 0;
    if (mode === "lce")
      return champLce.text !== "";
    if (mode === "bassin")
      return champBassin.text.trim().length >= 2;
    return empriseWkt !== "";
  }

  // Critères de filtrage des données à embarquer. Le serveur en tire la liste
  // des unités dont les inventaires partiront dans le GeoPackage du projet ;
  // il les croise, comme le fait la recherche.
  function filtreDonnees() {
    const liste = [];

    for (let i = 0; i < criteresActifs.length; ++i) {
      liste.push(critereDonnees(criteresActifs[i]));
    }

    return liste;
  }

  function critereDonnees(mode) {
    if (mode === "emprise") {
      // WKT en EPSG:4326, et sa boîte englobante au format attendu par le
      // champ `extent` du seed QFieldCloud : [xmin, ymin, xmax, ymax].
      return {
        "mode": "emprise",
        "wkt": empriseWkt,
        "bbox": empriseBbox
      };
    }

    if (mode === "region")
      return {
        "mode": "region",
        "valeur": comboRegion.currentValue ? comboRegion.currentValue : ""
      };

    if (mode === "bassin")
      return {
        "mode": "bassin",
        "valeur": champBassin.text.trim()
      };

    return {
      "mode": "lce",
      "valeur": champLce.text
    };
  }

  // La phrase affichée sous les pastilles : ce qui partira, ou ce qui manque.
  function explicationFiltre() {
    if (criteresActifs.length === 0)
      return qsTr("Cochez au moins un critère : le projet doit savoir quoi embarquer.");

    const manquants = [];
    for (let i = 0; i < criteresActifs.length; ++i) {
      if (!critereRenseigne(criteresActifs[i]))
        manquants.push(libelleCritere(criteresActifs[i]));
    }

    if (manquants.length > 0)
      return qsTr("À renseigner avant de créer : %1.").arg(manquants.join(qsTr(", ")));

    const portees = [];
    for (let j = 0; j < criteresActifs.length; ++j) {
      portees.push(porteeCritere(criteresActifs[j]));
    }

    if (portees.length === 1)
      return qsTr("Seront embarquées : les unités %1.").arg(portees[0]);

    return qsTr("Seront embarquées : les unités qui sont à la fois %1.").arg(portees.join(qsTr(" et ")));
  }

  function libelleCritere(mode) {
    for (let i = 0; i < criteresDisponibles.length; ++i) {
      if (criteresDisponibles[i]["cle"] === mode)
        return criteresDisponibles[i]["libelle"];
    }
    return mode;
  }

  function porteeCritere(mode) {
    if (mode === "region")
      return qsTr("de la région %1").arg(comboRegion.currentText);
    if (mode === "lce")
      return qsTr("du plan d'eau n° %1").arg(champLce.text);
    if (mode === "bassin")
      return qsTr("dont le bassin contient « %1 »").arg(champBassin.text.trim());
    return qsTr("situées dans l'emprise tracée");
  }

  // Le contexte de l'unité à créer. Ces noms sont ceux que lisent les valeurs
  // par défaut du formulaire QGIS : le serveur les inscrira comme variables du
  // projet livré, puisque ce n'est plus le projet ouvert qui recevra la saisie.
  function variablesProjet() {
    return {
      "code_region": "" + (comboRegion.currentValue ? comboRegion.currentValue : ""),
      "code_projet": "" + (comboProjet.currentValue ? comboProjet.currentValue : ""),
      "code_formulaire": "" + (comboType.currentValue ? comboType.currentValue : ""),
      "type_formulaire": "" + comboType.currentText,
      "code_lce": "" + champLce.text,
      "une_code_ident": champIdentifiant.text.trim()
    };
  }
}
