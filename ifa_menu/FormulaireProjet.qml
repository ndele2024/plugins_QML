// =============================================================================
//  FormulaireProjet — les champs d'un projet de sondage
// =============================================================================
//  Le formulaire commun à « Créer un projet » et à « Modifier / Afficher /
//  Supprimer un projet » : identification, statut, types d'UE planifiés,
//  description. Les deux fenêtres l'habillent (bandeaux, boutons, appels au
//  serveur) ; lui ne parle jamais au serveur.
//
//    n° → nom → année → région → statut → inventaire normalisé
//    → types d'UE planifiés (DialogueTypeUe) → description → commentaire
//
//  ---------------------------------------------------------------------------
//  CE QUI EST MODIFIABLE
//  ---------------------------------------------------------------------------
//  `champsModifiables` vaut `null` pour tout permettre (création), ou la liste
//  des champs que le serveur autorise (`droits.champs_modifiables`) — vide pour
//  un affichage seul. Un champ hors liste reste lisible, grisé ; un type d'UE
//  hors droits n'a ni « Ajouter » ni boutons de modification.
//
//  Seuls les champs modifiables sont vérifiés (`champsManquants`) : un projet
//  hérité sans région, dont on ne peut corriger que le nom, doit rester
//  enregistrable.
//
//  ---------------------------------------------------------------------------
//  API
//  ---------------------------------------------------------------------------
//    charger(projet)     remplit les champs ; `projet` devient la référence
//                        des changements. `null` : formulaire vierge.
//    valeurs()           tous les champs, au format du serveur
//    changements()       les champs modifiables qui diffèrent de la référence
//    champsManquants()   libellés des champs modifiables à compléter
//    choisirRegion(code) présélection de la région
//    saisieComplete, modifie   (liaisons)
//    saisieModifiee()    signal — à chaque frappe ou choix
//    rechargerTypes()    signal — « Réessayer » sur la liste des types
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

GridLayout {
  id: formulaire

  // ---------------------------------------------------------------------------
  //  Contexte, fourni par la fenêtre
  // ---------------------------------------------------------------------------
  property bool compact: false
  property color accent: Theme.mainColor
  property var referentiels: null

  // Zone où centrer le dialogue d'ajout de type — `zoneUtile` de la fenêtre.
  property Item zoneDialogue: null

  // Types du référentiel (`ServiceProjet.types`) et état de leur chargement.
  property var typesDisponibles: []
  property bool typesEnCours: false
  property string erreurTypes: ""
  property bool serveurJoignable: false

  // Statuts proposés. La création n'offre pas « Terminé ».
  property var statuts: [
    {
      code: "El",
      nom: qsTr("En élaboration")
    },
    {
      code: "Pr",
      nom: qsTr("En production")
    }
  ]

  // `null` : tout est modifiable. Sinon, la liste des champs permis.
  property var champsModifiables: null

  signal saisieModifiee
  signal rechargerTypes

  // ---------------------------------------------------------------------------
  //  Bornes — celles du serveur et des colonnes de la base
  // ---------------------------------------------------------------------------
  readonly property int longueurNumero: 20
  readonly property int longueurNom: 100
  readonly property int longueurDescription: 1000
  readonly property int longueurCommentaire: 4000
  readonly property int anneeMin: 1950
  readonly property int anneeCourante: new Date().getFullYear()
  readonly property int anneeMax: anneeCourante + 5

  // Les codes du type énuméré `region` qui ne sont pas des régions
  // administratives : `Referentiels.regions` ne les porte pas, le fonds si.
  readonly property var regionsSpeciales: [
    {
      code: "DDF",
      nom: qsTr("DDF - Dir. Développement de la faune")
    },
    {
      code: "DFA",
      nom: qsTr("DFA - Direction faune aquatique")
    },
    {
      code: "DPP",
      nom: qsTr("DPP - Programmes DGDOR - DPPP")
    },
    {
      code: "SP",
      nom: qsTr("SP - Stations piscicoles")
    }
  ]

  readonly property var regions: (referentiels ? referentiels.regions : []).concat(regionsSpeciales)

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  // Le projet chargé, référence des changements ; `null` en création.
  property var reference: null

  // Types d'UE ajoutés : [{ tue_code_ident, tue_nom, nb_impla_plani, nb_remes_plani }].
  property var typesAjoutes: []

  readonly property bool saisieComplete: champsManquants().length === 0
  readonly property bool modifie: Object.keys(changements()).length > 0

  columns: compact ? 1 : 2
  columnSpacing: 16
  rowSpacing: compact ? 4 : 10

  // =========================================================================
  //  Identification
  // =========================================================================
  Label {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true
    text: qsTr("Identification")
    font: Theme.strongTipFont
    color: formulaire.accent
  }

  // ---- N° du projet ----------------------------------------------------------
  Label {
    Layout.fillWidth: formulaire.compact
    text: qsTr("N° du projet") + " *"
    font: Theme.strongTipFont
    color: Theme.secondaryTextColor
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 2

    TextField {
      id: champNumero

      Layout.fillWidth: true
      font: Theme.strongFont
      enabled: formulaire.modifiable("pro_no")

      maximumLength: formulaire.longueurNumero
      placeholderText: qsTr("ex. 09-OG, 12_Conv_ENS")
      inputMethodHints: Qt.ImhNoPredictiveText

      onTextEdited: formulaire.saisieModifiee()
    }

    Label {
      Layout.fillWidth: true
      visible: champNumero.enabled
      text: qsTr("Unique dans la base IFA. C'est lui qui rattache les unités au projet.")
      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }
  }

  // ---- Nom du projet ---------------------------------------------------------
  Label {
    Layout.fillWidth: formulaire.compact
    text: qsTr("Nom du projet") + " *"
    font: Theme.strongTipFont
    color: Theme.secondaryTextColor
  }

  TextField {
    id: champNom

    Layout.fillWidth: true
    enabled: formulaire.modifiable("pro_nom")

    maximumLength: formulaire.longueurNom
    placeholderText: qsTr("ex. Inventaire des lacs de la Côte-Nord")

    onTextEdited: formulaire.saisieModifiee()
  }

  // ---- Année -----------------------------------------------------------------
  Label {
    Layout.fillWidth: formulaire.compact
    text: qsTr("Année") + " *"
    font: Theme.strongTipFont
    color: Theme.secondaryTextColor
  }

  TextField {
    id: champAnnee

    Layout.fillWidth: true
    enabled: formulaire.modifiable("pro_an")

    text: "" + formulaire.anneeCourante
    maximumLength: 4
    inputMethodHints: Qt.ImhDigitsOnly
    validator: IntValidator {
      bottom: formulaire.anneeMin
      top: formulaire.anneeMax
    }

    // Une année hors bornes se voit avant l'appui sur le bouton.
    color: acceptableInput || text === "" ? Theme.mainTextColor : Theme.errorColor

    onTextEdited: formulaire.saisieModifiee()
  }

  // ---- Région administrative -------------------------------------------------
  Label {
    Layout.fillWidth: formulaire.compact
    text: qsTr("Région administrative") + " *"
    font: Theme.strongTipFont
    color: Theme.secondaryTextColor
  }

  ComboBox {
    id: comboRegion

    Layout.fillWidth: true
    enabled: formulaire.modifiable("rad_no")

    textRole: "nom"
    valueRole: "code"
    currentIndex: -1
    model: formulaire.regions

    displayText: currentIndex === -1 ? (enabled ? qsTr("Aucune région sélectionnée") : qsTr("Non renseignée")) : currentText

    onActivated: formulaire.saisieModifiee()
  }

  // =========================================================================
  //  Statut
  // =========================================================================
  Rectangle {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true
    Layout.topMargin: 10
    Layout.preferredHeight: 1
    color: Theme.controlBorderColor
  }

  Label {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true
    text: qsTr("Statut")
    font: Theme.strongTipFont
    color: formulaire.accent
  }

  Label {
    Layout.fillWidth: formulaire.compact
    text: qsTr("Statut du projet")
    font: Theme.strongTipFont
    color: Theme.secondaryTextColor
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 2

    ComboBox {
      id: comboStatut

      Layout.fillWidth: true
      enabled: formulaire.modifiable("pro_code_statu")

      textRole: "nom"
      valueRole: "code"
      currentIndex: 0
      model: formulaire.statuts

      onActivated: formulaire.saisieModifiee()
    }

    Label {
      Layout.fillWidth: true
      visible: comboStatut.enabled
      text: {
        if (comboStatut.currentValue === "Pr")
          return qsTr("Le projet peut recevoir des unités : il apparaît dans « Créer une UE ». Seul un administrateur pourra ensuite le modifier.");
        if (comboStatut.currentValue === "Te")
          return qsTr("Le projet est terminé : il n'apparaît plus dans « Créer une UE ».");
        return qsTr("Le projet est déclaré mais n'apparaît pas encore dans « Créer une UE ».");
      }
      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }
  }

  Label {
    Layout.fillWidth: formulaire.compact
    text: qsTr("Inventaire normalisé")
    font: Theme.strongTipFont
    color: Theme.secondaryTextColor
  }

  CheckBox {
    id: caseNormalise

    Layout.fillWidth: true
    enabled: formulaire.modifiable("pro_ind_inven_norma")

    text: checked ? qsTr("Oui") : qsTr("Non")
    font: Theme.tipFont
    checked: false

    onToggled: formulaire.saisieModifiee()
  }

  // =========================================================================
  //  Types d'UE planifiés
  // =========================================================================
  Rectangle {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true
    Layout.topMargin: 10
    Layout.preferredHeight: 1
    color: Theme.controlBorderColor
  }

  Label {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true
    text: formulaire.typesModifiables ? qsTr("Types d'UE planifiés") + " *" : qsTr("Types d'UE planifiés")
    font: Theme.strongTipFont
    color: formulaire.accent
  }

  Label {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true

    text: {
      const n = formulaire.typesAjoutes.length;
      if (n > 0)
        return qsTr("%n type(s) d'UE.", "", n);
      if (!formulaire.typesModifiables)
        return qsTr("Aucun type d'UE associé à ce projet.");
      return qsTr("Aucun type d'UE ajouté. Ajoutez au moins un type, avec ses implantations et ses remesurages planifiés.");
    }
    font: Theme.tinyFont
    color: Theme.secondaryTextColor
    wrapMode: Text.WordWrap
  }

  // ---- Chargement de la liste des types --------------------------------------
  RowLayout {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true

    visible: formulaire.typesModifiables && formulaire.typesEnCours
    spacing: 10

    BusyIndicator {
      Layout.preferredWidth: 28
      Layout.preferredHeight: 28
      running: parent.visible
    }

    Label {
      Layout.fillWidth: true
      text: qsTr("Chargement des types d'UE…")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
    }
  }

  // ---- Liste des types indisponible --------------------------------------------
  //  Sans elle, aucun type ne peut être ajouté : le bandeau dit pourquoi et
  //  offre de recommencer.
  Rectangle {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true
    Layout.preferredHeight: blocErreurTypes.implicitHeight + 20

    visible: formulaire.typesModifiables && !formulaire.typesEnCours && formulaire.typesDisponibles.length === 0

    radius: 10
    color: Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.14)
    border.width: 1
    border.color: Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.4)

    ColumnLayout {
      id: blocErreurTypes

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 8

      Label {
        Layout.fillWidth: true
        text: formulaire.erreurTypes !== "" ? qsTr("Liste des types d'UE indisponible : %1").arg(formulaire.erreurTypes) : qsTr("La liste des types d'UE n'est pas encore chargée.")
        font: Theme.tinyFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap
      }

      QfButton {
        Layout.alignment: Qt.AlignRight
        text: qsTr("Réessayer")
        enabled: formulaire.serveurJoignable
        bgcolor: "transparent"
        color: formulaire.accent
        borderColor: formulaire.accent
        onClicked: formulaire.rechargerTypes()
      }
    }
  }

  // ---- Les types ajoutés -------------------------------------------------------
  ColumnLayout {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true

    visible: formulaire.typesAjoutes.length > 0
    spacing: 6

    Repeater {
      model: formulaire.typesAjoutes

      delegate: Rectangle {
        id: ligneType

        readonly property var typeUe: modelData

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(contenuLigne.implicitHeight + 14, 48)

        radius: 8
        color: Qt.rgba(formulaire.accent.r, formulaire.accent.g, formulaire.accent.b, 0.08)
        border.width: 1
        border.color: Qt.rgba(formulaire.accent.r, formulaire.accent.g, formulaire.accent.b, 0.5)

        RowLayout {
          id: contenuLigne

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 12
          anchors.rightMargin: 4
          spacing: 4

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
              Layout.fillWidth: true
              text: ligneType.typeUe["tue_nom"]
              font: Theme.strongTipFont
              color: Theme.mainTextColor
              wrapMode: Text.WordWrap
            }

            Label {
              Layout.fillWidth: true
              text: qsTr("%n implantation(s)", "", ligneType.typeUe["nb_impla_plani"]) + "  ·  " + qsTr("%n remesurage(s) planifié(s)", "", ligneType.typeUe["nb_remes_plani"])
              font: Theme.tinyFont
              color: Theme.secondaryTextColor
              wrapMode: Text.WordWrap
            }
          }

          QfToolButton {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            visible: formulaire.typesModifiables
            round: true
            bgcolor: "transparent"
            iconSource: Theme.getThemeVectorIcon("ic_edit_attributes_white_24dp")
            iconColor: formulaire.accent
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Modifier les nombres planifiés")
            onClicked: dialogueType.modifier(ligneType.typeUe, [ligneType.typeUe])
          }

          QfToolButton {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            visible: formulaire.typesModifiables
            round: true
            bgcolor: "transparent"
            iconSource: Theme.getThemeVectorIcon("ic_delete_forever_white_24dp")
            iconColor: Theme.errorColor
            ToolTip.visible: hovered
            ToolTip.text: qsTr("Retirer ce type du projet")
            onClicked: formulaire.retirerType(ligneType.typeUe["tue_code_ident"])
          }
        }
      }
    }
  }

  // ---- Ajouter ------------------------------------------------------------------
  QfButton {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true

    visible: formulaire.typesModifiables && formulaire.typesDisponibles.length > 0
    enabled: formulaire.typesRestants().length > 0
    text: formulaire.typesRestants().length > 0 ? qsTr("Ajouter un type d'UE") : qsTr("Tous les types d'UE sont ajoutés")
    icon.source: Theme.getThemeVectorIcon("ic_add_white_24dp")
    bgcolor: "transparent"
    color: formulaire.accent
    borderColor: formulaire.accent
    onClicked: dialogueType.ajouter(formulaire.typesRestants())
  }

  // =========================================================================
  //  Description
  // =========================================================================
  Rectangle {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true
    Layout.topMargin: 10
    Layout.preferredHeight: 1
    color: Theme.controlBorderColor
  }

  Label {
    Layout.columnSpan: formulaire.columns
    Layout.fillWidth: true
    text: qsTr("Description")
    font: Theme.strongTipFont
    color: formulaire.accent
  }

  Label {
    Layout.fillWidth: formulaire.compact
    Layout.alignment: Qt.AlignTop
    Layout.topMargin: formulaire.compact ? 0 : 8
    text: qsTr("Description")
    font: Theme.strongTipFont
    color: Theme.secondaryTextColor
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 2

    TextArea {
      id: zoneDescription

      Layout.fillWidth: true
      Layout.minimumHeight: 72
      enabled: formulaire.modifiable("pro_descr")

      placeholderText: enabled ? qsTr("Objectifs, territoire, méthode…") : ""
      wrapMode: TextEdit.Wrap
      font: Theme.tipFont

      onTextChanged: formulaire.borner(zoneDescription, formulaire.longueurDescription)
    }

    Label {
      Layout.alignment: Qt.AlignRight
      visible: zoneDescription.enabled
      text: "%1 / %2".arg(zoneDescription.length).arg(formulaire.longueurDescription)
      font: Theme.tinyFont
      color: zoneDescription.length >= formulaire.longueurDescription ? Theme.warningColor : Theme.secondaryTextColor
    }
  }

  Label {
    Layout.fillWidth: formulaire.compact
    Layout.alignment: Qt.AlignTop
    Layout.topMargin: formulaire.compact ? 0 : 8
    text: qsTr("Commentaire")
    font: Theme.strongTipFont
    color: Theme.secondaryTextColor
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 2

    TextArea {
      id: zoneCommentaire

      Layout.fillWidth: true
      Layout.minimumHeight: 72
      enabled: formulaire.modifiable("pro_com")

      placeholderText: enabled ? qsTr("Remarques libres") : ""
      wrapMode: TextEdit.Wrap
      font: Theme.tipFont

      onTextChanged: formulaire.borner(zoneCommentaire, formulaire.longueurCommentaire)
    }

    Label {
      Layout.alignment: Qt.AlignRight
      visible: zoneCommentaire.enabled
      text: "%1 / %2".arg(zoneCommentaire.length).arg(formulaire.longueurCommentaire)
      font: Theme.tinyFont
      color: zoneCommentaire.length >= formulaire.longueurCommentaire ? Theme.warningColor : Theme.secondaryTextColor
    }
  }

  // ---------------------------------------------------------------------------
  //  Ajout et modification d'un type d'UE
  // ---------------------------------------------------------------------------
  DialogueTypeUe {
    id: dialogueType

    zoneParente: formulaire.zoneDialogue
    accent: formulaire.accent

    onValide: function (typeUe) {
      formulaire.enregistrerType(typeUe);
    }
  }

  // ===========================================================================
  //  API
  // ===========================================================================
  readonly property bool typesModifiables: modifiable("types_ue")

  function modifiable(champ) {
    return champsModifiables === null || champsModifiables.indexOf(champ) !== -1;
  }

  // Remplit le formulaire ; `projet` devient la référence des changements.
  function charger(projet) {
    reference = projet;

    if (!projet) {
      champNumero.text = "";
      champNom.text = "";
      champAnnee.text = "" + anneeCourante;
      comboRegion.currentIndex = -1;
      comboStatut.currentIndex = 0;
      caseNormalise.checked = false;
      typesAjoutes = [];
      zoneDescription.text = "";
      zoneCommentaire.text = "";
      return;
    }

    champNumero.text = projet["pro_no"] || "";
    champNom.text = projet["pro_nom"] || "";
    champAnnee.text = projet["pro_an"] ? "" + projet["pro_an"] : "";
    comboRegion.currentIndex = projet["rad_no"] ? comboRegion.indexOfValue(projet["rad_no"]) : -1;
    comboStatut.currentIndex = Math.max(0, comboStatut.indexOfValue(projet["pro_code_statu"]));
    caseNormalise.checked = projet["pro_ind_inven_norma"] === "O";
    typesAjoutes = (projet["types_ue"] || []).slice();
    zoneDescription.text = projet["pro_descr"] || "";
    zoneCommentaire.text = projet["pro_com"] || "";
  }

  function choisirRegion(code) {
    if (code)
      comboRegion.currentIndex = comboRegion.indexOfValue("" + code);
  }

  function focusPremierChamp() {
    if (champNumero.enabled)
      champNumero.forceActiveFocus();
    else if (champNom.enabled)
      champNom.forceActiveFocus();
  }

  // Tous les champs, au format du serveur.
  function valeurs() {
    return {
      "pro_no": champNumero.text.trim(),
      "pro_nom": champNom.text.trim(),
      "pro_an": parseInt(champAnnee.text, 10),
      "rad_no": comboRegion.currentIndex >= 0 ? "" + comboRegion.currentValue : "",
      "pro_code_statu": "" + comboStatut.currentValue,
      "pro_ind_inven_norma": caseNormalise.checked,
      "types_ue": typesACreer(),
      "pro_descr": zoneDescription.text.trim(),
      "pro_com": zoneCommentaire.text.trim()
    };
  }

  // Les champs modifiables dont la valeur diffère de la référence. En
  // création (pas de référence), tous les champs.
  function changements() {
    const v = valeurs();

    if (!reference)
      return v;

    const ref = {
      "pro_no": reference["pro_no"] || "",
      "pro_nom": reference["pro_nom"] || "",
      "pro_an": reference["pro_an"] || 0,
      "rad_no": reference["rad_no"] || "",
      "pro_code_statu": reference["pro_code_statu"] || "",
      "pro_ind_inven_norma": reference["pro_ind_inven_norma"] === "O",
      "types_ue": reference["types_ue"] || [],
      "pro_descr": reference["pro_descr"] || "",
      "pro_com": reference["pro_com"] || ""
    };

    const resultat = {};
    for (const champ in v) {
      if (!modifiable(champ))
        continue;

      const differe = champ === "types_ue" ? cleTypes(v[champ]) !== cleTypes(ref[champ]) : v[champ] !== ref[champ];
      if (differe)
        resultat[champ] = v[champ];
    }
    return resultat;
  }

  // Les champs modifiables à compléter, par leur libellé.
  function champsManquants() {
    const manquants = [];

    if (modifiable("pro_no") && champNumero.text.trim() === "")
      manquants.push(qsTr("n° du projet"));
    if (modifiable("pro_nom") && champNom.text.trim() === "")
      manquants.push(qsTr("nom"));
    if (modifiable("pro_an") && !champAnnee.acceptableInput)
      manquants.push(qsTr("année entre %1 et %2").arg(anneeMin).arg(anneeMax));
    if (modifiable("rad_no") && comboRegion.currentIndex < 0)
      manquants.push(qsTr("région"));
    // Un projet hérité sans type reste enregistrable tant qu'on ne touche pas
    // à ses types ; un projet qui en a ne peut pas tous les perdre.
    if (typesModifiables && typesAjoutes.length === 0 && (!reference || (reference["types_ue"] || []).length > 0))
      manquants.push(qsTr("au moins un type d'UE"));

    return manquants;
  }

  // ---- Types d'UE ---------------------------------------------------------------
  //  `typesAjoutes` est remplacé, jamais modifié en place : une liaison QML ne
  //  voit pas la modification d'un tableau JavaScript, seulement l'affectation
  //  d'un nouveau.

  // Ajoute le type, ou remplace ses nombres s'il est déjà là (modification).
  function enregistrerType(typeUe) {
    const liste = typesAjoutes.slice();
    const i = liste.findIndex(function (t) {
      return t["tue_code_ident"] === typeUe["tue_code_ident"];
    });

    if (i >= 0)
      liste[i] = typeUe;
    else
      liste.push(typeUe);

    typesAjoutes = liste;
    saisieModifiee();
  }

  function retirerType(code) {
    typesAjoutes = typesAjoutes.filter(function (t) {
      return t["tue_code_ident"] !== code;
    });
    saisieModifiee();
  }

  // Les types du référentiel pas encore ajoutés : ce que propose le dialogue.
  function typesRestants() {
    return typesDisponibles.filter(function (t) {
      return !typesAjoutes.some(function (a) {
        return a["tue_code_ident"] === t["tue_code_ident"];
      });
    });
  }

  // Ce qui part au serveur : identifiant et nombres, le libellé reste ici.
  function typesACreer() {
    return typesAjoutes.map(function (t) {
      return {
        "tue_code_ident": t["tue_code_ident"],
        "nb_impla_plani": t["nb_impla_plani"],
        "nb_remes_plani": t["nb_remes_plani"]
      };
    });
  }

  // Comparaison indépendante de l'ordre.
  function cleTypes(types) {
    return types.map(function (t) {
      return t["tue_code_ident"] + ":" + t["nb_impla_plani"] + ":" + t["nb_remes_plani"];
    }).sort().join("|");
  }

  // `TextArea` n'a pas de `maximumLength` : l'excédent — un collage, surtout —
  // est retiré à la frappe, et le compteur sous la zone dit où on en est.
  function borner(zone, longueurMax) {
    if (zone.length > longueurMax)
      zone.remove(longueurMax, zone.length);
    if (zone.activeFocus)
      saisieModifiee();
  }
}
