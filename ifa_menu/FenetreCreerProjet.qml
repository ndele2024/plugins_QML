// =============================================================================
//  FenetreCreerProjet — création d'un projet de sondage
// =============================================================================
//  Déclare un nouveau projet dans la base IFA (`ifa_data.proje_sonda`) et les
//  types d'UE qu'il planifie (`ifa_data.proje_type_unite_echan`). Les champs
//  sont ceux de `FormulaireProjet`, commun avec « Modifier / Afficher /
//  Supprimer un projet » ; cette fenêtre n'y ajoute que son habillage et
//  l'appel au serveur.
//
//  ---------------------------------------------------------------------------
//  LES TYPES D'UE
//  ---------------------------------------------------------------------------
//  Un projet planifie plusieurs types d'UE, et un type d'UE se retrouve dans
//  plusieurs projets. Ajouter un type, c'est dire ce qu'on y planifie : le
//  bouton « Ajouter un type d'UE » ouvre `DialogueTypeUe`, qui demande le type,
//  le nombre d'implantations (au moins une) et le nombre de remesurages (zéro
//  ou plus).
//
//  Les types proposés viennent du serveur (`GET types-ue/`), à l'ouverture de
//  la fenêtre : la liste codée en dur de `Referentiels` en omet plusieurs, et
//  l'association se fait par identifiant.
//
//  ---------------------------------------------------------------------------
//  CE QUE FAIT « CRÉER »
//  ---------------------------------------------------------------------------
//  Un seul appel, par `ServiceProjet` : le serveur vérifie que le n° est libre
//  et que les types existent, inscrit le projet et ses types dans une même
//  transaction, et rend le tout. Le projet existe dès la réponse — il n'y a pas
//  de projet QFieldCloud à préparer ni à ouvrir, contrairement à « Créer une
//  UE ».
//
//  Le serveur fixe lui-même ce qui ne se saisit pas : l'identifiant (UUID), les
//  dates de création, de statut et de première mise en production, le code de
//  l'utilisateur — qui devient le créateur du projet, seul à pouvoir le
//  supprimer avec les administrateurs —, et la version de type.
//
//  ---------------------------------------------------------------------------
//  APRÈS LA CRÉATION
//  ---------------------------------------------------------------------------
//  La liste des projets de « Créer une UE » est lue dans la couche
//  « proje_sonda » du projet ouvert, qui ne verra le nouveau projet qu'après
//  une synchronisation. Pour ne pas attendre, un projet créé **en production**
//  est ajouté tout de suite à cette liste (`Referentiels.ajouterProjet`) : on
//  peut enchaîner sur la création de ses unités. Un projet en élaboration n'y
//  figure pas — c'est la règle de la liste, pas une omission.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

IfaPopup {
  id: fenetre

  titre: qsTr("Créer un projet")
  soustitre: qsTr("Nouveau projet de sondage")
  icone: "ic_add_white_24dp"
  accent: Theme.mainColor

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  // Le dernier refus du serveur, affiché dans le formulaire plutôt qu'en
  // notification : un n° déjà pris doit rester sous les yeux le temps de le
  // corriger. Effacé dès que la saisie change.
  property string erreurServeur: ""

  // Échec du chargement de la liste des types, affiché avec « Réessayer ».
  property string erreurTypes: ""

  readonly property bool serveurJoignable: session !== null && session.disponible

  onOpened: {
    // La fenêtre peut se rouvrir sans être rechargée : la liste déjà reçue
    // reste valable.
    if (service.types.length === 0 && !service.typesEnCours && serveurJoignable)
      chargerTypes();

    if (referentiels)
      prepositionnerRegion();
    formulaire.focusPremierChamp();
  }

  // ---- Avertissement : serveur injoignable ---------------------------------
  Rectangle {
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
        text: qsTr("Aucune connexion QFieldCloud active : le projet ne peut pas être enregistré. Connectez-vous au serveur depuis QField.")
        font: Theme.tinyFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Formulaire
  // ---------------------------------------------------------------------------
  FormulaireProjet {
    id: formulaire

    Layout.fillWidth: true

    compact: fenetre.compact
    accent: fenetre.accent
    referentiels: fenetre.referentiels
    zoneDialogue: fenetre.zoneUtile

    typesDisponibles: service.types
    typesEnCours: service.typesEnCours
    erreurTypes: fenetre.erreurTypes
    serveurJoignable: fenetre.serveurJoignable

    onSaisieModifiee: fenetre.erreurServeur = ""
    onRechargerTypes: fenetre.chargerTypes()
  }

  // ---- Ce qui manque, ou ce que le serveur a refusé -------------------------
  //  Le bouton « Créer » reste éteint tant que la saisie est incomplète : la
  //  phrase dit pourquoi, sans quoi rien à l'écran ne le dirait.
  Label {
    Layout.fillWidth: true
    Layout.topMargin: 8

    visible: !formulaire.saisieComplete && fenetre.erreurServeur === ""
    text: qsTr("À renseigner avant de créer : %1.").arg(formulaire.champsManquants().join(qsTr(", ")))
    font: Theme.tinyFont
    color: Theme.secondaryTextColor
    wrapMode: Text.WordWrap
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.preferredHeight: texteErreurServeur.implicitHeight + 20

    visible: fenetre.erreurServeur !== ""

    radius: 10
    color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.14)
    border.width: 1
    border.color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.4)

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
        color: Theme.errorColor
        sourceSize: Qt.size(40, 40)
      }

      Label {
        id: texteErreurServeur
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: fenetre.erreurServeur
        font: Theme.tinyFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }
    }
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
        service.annuler();
        fenetre.close();
      }
    },
    QfButton {
      text: service.enCours ? qsTr("Enregistrement…") : qsTr("Créer")
      enabled: formulaire.saisieComplete && fenetre.serveurJoignable && !service.enCours
      bgcolor: fenetre.accent
      color: fenetre.surAccent
      onClicked: fenetre.creerProjet()
    }
  ]

  // ===========================================================================
  //  Enregistrement
  // ===========================================================================
  ServiceProjet {
    id: service

    session: fenetre.session

    onEnCoursChanged: fenetre.activite = enCours ? qsTr("Enregistrement du projet dans la base IFA…") : ""

    onCree: function (projet) {
      if (fenetre.referentiels)
        fenetre.referentiels.ajouterProjet(projet);

      const nombreTypes = projet["types_ue"] ? projet["types_ue"].length : 0;
      fenetre.avertir(qsTr("Projet %1 créé avec %n type(s) d'UE.", "", nombreTypes).arg(projet["pro_no"]), "success");
      fenetre.close();
    }

    onTypesCharges: fenetre.erreurTypes = ""

    onEchecTypes: function (message) {
      fenetre.erreurTypes = message;
    }

    // La fenêtre reste ouverte, la saisie intacte : l'appui peut être rejoué
    // une fois la cause levée. Un n° déjà pris (409) renvoie au champ fautif.
    onEchec: function (message, statut) {
      fenetre.erreurServeur = message;
      if (statut === 409)
        formulaire.focusPremierChamp();
    }
  }

  // ===========================================================================
  //  Fonctions
  // ===========================================================================
  function creerProjet() {
    erreurServeur = "";
    service.creer(formulaire.valeurs());
  }

  function chargerTypes() {
    erreurTypes = "";
    service.chargerTypes();
  }

  // Présélectionne la région : variable de projet si elle existe, sinon
  // position GPS courante. Même règle que « Créer une UE ».
  function prepositionnerRegion() {
    let codeRegion = referentiels.variableProjet("code_region");

    if (codeRegion === null || codeRegion === undefined || codeRegion === "")
      codeRegion = referentiels.regionParGps();

    formulaire.choisirRegion(codeRegion);
  }
}
