// =============================================================================
//  FenetreCreerUE — création d'une unité d'échantillonnage
// =============================================================================
//  Reprend le formulaire du plugin projet
//  « v7_default_config_pkey_ObvervationGenTest_cloud_qfield.qml » :
//
//    région administrative → projet → type d'UE → n° de plan d'eau (LCE)
//    → identifiant UE (composé automatiquement, modifiable à la main)
//
//  À la validation, les valeurs sont posées comme variables de projet (elles
//  alimentent les valeurs par défaut du formulaire QGIS), puis le formulaire
//  de saisie de la couche « mesurage » est ouvert.
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
import org.qgis
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

  readonly property var coucheMesurage: referentiels ? referentiels.couche("mesurage") : null

  // ---- Filtre des données à embarquer ---------------------------------------
  // Détermine le sous-ensemble de données extrait dans les GeoPackage du projet
  // dérivé. Les trois modes reprennent ceux de `extract_ipe_subset.py`, avec le
  // n° de plan d'eau en plus.
  readonly property var modesFiltre: ["region", "lce", "emprise"]
  property string modeFiltre: "region"

  // Emprise personnalisée, renseignée par SelecteurEmprise.
  property string empriseWkt: ""
  property var empriseBbox: null
  property int empriseNombreSommets: 0

  // Sommets en CRS carte, conservés pour pouvoir reprendre un tracé existant.
  property var empriseSommets: []

  readonly property bool filtrePret: {
    if (modeFiltre === "region")
      return comboRegion.currentIndex >= 0;
    if (modeFiltre === "lce")
      return champLce.text !== "";
    return empriseWkt !== "";
  }

  readonly property bool saisieComplete: comboRegion.currentIndex >= 0 && comboType.currentIndex >= 0 && champIdentifiant.text.trim() !== "" && champIdentifiant.text.indexOf("[") === -1 && filtrePret

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

    // ---- Avertissement : projet incomplet ------------------------------------
    Rectangle {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.preferredHeight: texteAvertissement.implicitHeight + 20
      Layout.bottomMargin: 6

      visible: fenetre.coucheMesurage === null

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
          text: qsTr("La couche « mesurage » est absente du projet ouvert : la saisie ne pourra pas être lancée.")
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
      text: qsTr("Filtrer sur")
      font: Theme.strongTipFont
      color: Theme.secondaryTextColor
    }

    QfToggleButtonGroup {
      id: choixFiltre

      Layout.fillWidth: true
      // Le composant fixe sa `height` d'après son Flow interne ; sans cette
      // hauteur minimale, le GridLayout l'écraserait à zéro.
      Layout.minimumHeight: choixFiltre.height

      selectedIndex: 0
      model: [qsTr("Région"), qsTr("N° de plan d'eau"), qsTr("Emprise personnalisée")]

      onItemSelected: function (index, modelData) {
        fenetre.modeFiltre = fenetre.modesFiltre[index];
      }
    }

    // ---- Explication du critère retenu -----------------------------------------
    Label {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true

      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap

      text: {
        if (fenetre.modeFiltre === "region") {
          return comboRegion.currentIndex >= 0 ? qsTr("Toutes les unités de la région %1 seront embarquées.").arg(comboRegion.currentText) : qsTr("Choisissez d'abord une région administrative ci-dessus.");
        }
        if (fenetre.modeFiltre === "lce") {
          return champLce.text !== "" ? qsTr("Seules les unités du plan d'eau n° %1 seront embarquées.").arg(champLce.text) : qsTr("Saisissez d'abord un n° de plan d'eau ci-dessus.");
        }
        return qsTr("Seules les unités situées dans l'emprise tracée seront embarquées.");
      }
    }

    // ---- Emprise personnalisée -------------------------------------------------
    Rectangle {
      Layout.columnSpan: grille.columns
      Layout.fillWidth: true
      Layout.preferredHeight: blocEmprise.implicitHeight + 24

      visible: fenetre.modeFiltre === "emprise"

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
      onClicked: fenetre.close()
    },
    QfButton {
      text: qsTr("Créer")
      enabled: fenetre.saisieComplete && fenetre.coucheMesurage !== null
      bgcolor: fenetre.accent
      color: fenetre.surAccent
      onClicked: fenetre.creerUe()
    }
  ]

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

  // Pose les variables de projet puis ouvre le formulaire de saisie.
  function creerUe() {
    referentiels.definirVariableProjet("code_region", comboRegion.currentValue);
    referentiels.definirVariableProjet("code_formulaire", comboType.currentValue);
    referentiels.definirVariableProjet("type_formulaire", comboType.currentText);
    referentiels.definirVariableProjet("code_lce", champLce.text);
    referentiels.definirVariableProjet("une_code_ident", champIdentifiant.text.trim());
    referentiels.definirVariableProjet("code_projet", comboProjet.currentValue);

    enregistrerFiltre();

    if (ouvrirFormulaireMesurage()) {
      close();
    }
  }

  // Critère de filtrage des données à embarquer, conservé en variables de
  // projet. C'est ce que le point d'accès QFieldCloud consommera pour extraire
  // le sous-ensemble dans les GeoPackage du projet dérivé.
  function enregistrerFiltre() {
    referentiels.definirVariableProjet("filtre_mode", modeFiltre);

    let valeur = "";
    if (modeFiltre === "region")
      valeur = comboRegion.currentValue ? comboRegion.currentValue : "";
    else if (modeFiltre === "lce")
      valeur = champLce.text;

    referentiels.definirVariableProjet("filtre_valeur", valeur);

    // WKT en EPSG:4326, et sa boîte englobante au format attendu par le champ
    // `extent` du seed QFieldCloud : [xmin, ymin, xmax, ymax].
    referentiels.definirVariableProjet("filtre_emprise_wkt", modeFiltre === "emprise" ? empriseWkt : "");
    referentiels.definirVariableProjet("filtre_emprise_bbox", modeFiltre === "emprise" && empriseBbox ? JSON.stringify(empriseBbox) : "");
  }

  // Bascule QField sur la couche « mesurage » et ouvre le tiroir de saisie sur
  // une nouvelle entité sans géométrie.
  function ouvrirFormulaireMesurage() {
    const tableauDeBord = iface.findItemByObjectName("dashBoard");
    const tiroirFormulaire = iface.findItemByObjectName("overlayFeatureFormDrawer");

    if (!tableauDeBord || !tiroirFormulaire) {
      avertir(qsTr("Interface QField inattendue : impossible d'ouvrir le formulaire."), "error");
      return false;
    }

    if (!coucheMesurage) {
      avertir(qsTr("La couche « mesurage » est absente du projet ouvert."), "warning");
      return false;
    }

    tableauDeBord.activeLayer = coucheMesurage;
    tableauDeBord.ensureEditableLayerSelected();

    const geometrie = GeometryUtils.createGeometryFromWkt("");
    const entite = FeatureUtils.createFeature(tableauDeBord.activeLayer, geometrie);

    tiroirFormulaire.featureModel.feature = entite;
    tiroirFormulaire.state = "Add";
    tiroirFormulaire.open();

    return true;
  }
}
