// =============================================================================
//  FenetreModifierProjet — afficher, modifier ou supprimer un projet de sondage
// =============================================================================
//  Deux vues dans la même fenêtre :
//
//    LISTE   tous les projets de la base (serveur, `GET projets-sondage/`),
//            filtrés à la frappe : n° ou nom, région, « mes projets » ;
//    DÉTAIL  le projet choisi dans `FormulaireProjet` — le même formulaire que
//            « Créer un projet » —, ses types d'UE, et les boutons
//            « Supprimer » et « Enregistrer ».
//
//  ---------------------------------------------------------------------------
//  QUI PEUT QUOI
//  ---------------------------------------------------------------------------
//  Le serveur calcule les droits de l'utilisateur sur chaque projet
//  (`droits`, voir `projet_gestion.py`) ; la fenêtre s'en sert pour se
//  présenter, et le serveur les revérifie à chaque écriture.
//
//    Modifier   un projet en production : administrateur seulement — sinon la
//               fenêtre est en affichage seul ;
//               un projet utilisé par une UE : nom et description seulement,
//               administrateur compris.
//    Supprimer  administrateur : tout projet ;
//               utilisateur standard : ses propres projets, hors production ;
//               jamais un projet utilisé par une UE ;
//               toujours après confirmation et mot de passe.
//
//  Un bandeau, en tête du détail, dit ce qui est modifiable et pourquoi. Un
//  appui sur « Supprimer » qui ne serait pas permis ouvre une alerte qui en
//  donne la raison, plutôt qu'un bouton éteint qui ne dirait rien.
//
//  Est administrateur un membre de rôle `admin` de l'organisation IFA
//  (`ifa_team`), ou un superutilisateur de QFieldCloud. Le sous-titre de la
//  fenêtre l'indique.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

IfaPopup {
  id: fenetre

  titre: qsTr("Projets de sondage")
  soustitre: admin ? qsTr("Afficher, modifier, supprimer — administrateur") : qsTr("Afficher, modifier ou supprimer un projet")
  icone: "ic_edit_attributes_white_24dp"
  accent: Theme.mainColor

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  // "liste" ou "detail".
  property string vue: "liste"

  // Tous les projets, tels que le serveur les rend (avec `droits`).
  property var projets: []
  property bool admin: false
  property bool listeChargee: false
  property string erreurListe: ""

  // Le projet ouvert dans la vue détail, tel que le serveur l'a rendu.
  property var projetCourant: null

  // Refus du serveur à l'enregistrement — affiché jusqu'à la prochaine saisie.
  property string erreurServeur: ""
  property string erreurTypes: ""

  readonly property var droitsCourants: projetCourant ? projetCourant["droits"] : null
  readonly property bool modifiable: droitsCourants !== null && droitsCourants["modifiable"]

  readonly property bool serveurJoignable: session !== null && session.disponible

  readonly property var libellesStatut: ({
      "El": qsTr("En élaboration"),
      "Pr": qsTr("En production"),
      "Te": qsTr("Terminé")
    })

  // La liste filtrée — recalculée à chaque frappe.
  readonly property var projetsFiltres: {
    const texte = champRecherche.text.trim().toLowerCase();
    const region = comboFiltreRegion.currentIndex > 0 ? "" + comboFiltreRegion.currentValue : "";
    const miens = caseMiens.checked;

    return projets.filter(function (p) {
      if (texte !== "" && (p["pro_no"] + " " + p["pro_nom"]).toLowerCase().indexOf(texte) === -1)
        return false;
      if (region !== "" && p["rad_no"] !== region)
        return false;
      if (miens && !p["droits"]["createur"])
        return false;
      return true;
    });
  }

  onOpened: {
    if (!listeChargee && service.gestionEnCours === "")
      chargerListe();
  }

  // ===========================================================================
  //  VUE LISTE
  // ===========================================================================
  ColumnLayout {
    Layout.fillWidth: true
    visible: fenetre.vue === "liste"
    spacing: 8

    // ---- Avertissement : serveur injoignable ---------------------------------
    Label {
      Layout.fillWidth: true
      visible: !fenetre.serveurJoignable
      text: qsTr("Aucune connexion QFieldCloud active : la liste des projets ne peut pas être chargée. Connectez-vous au serveur depuis QField.")
      font: Theme.tinyFont
      color: Theme.warningColor
      wrapMode: Text.WordWrap
    }

    // ---- Filtres ------------------------------------------------------------------
    TextField {
      id: champRecherche

      Layout.fillWidth: true
      placeholderText: qsTr("Rechercher par n° ou nom de projet")
      inputMethodHints: Qt.ImhNoPredictiveText
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      ComboBox {
        id: comboFiltreRegion

        Layout.fillWidth: true

        textRole: "nom"
        valueRole: "code"
        currentIndex: 0
        model: [
          {
            "code": "",
            "nom": qsTr("Toutes les régions")
          }
        ].concat(fenetre.referentiels ? fenetre.referentiels.regions : [])
      }

      CheckBox {
        id: caseMiens

        text: qsTr("Mes projets")
        font: Theme.tipFont
      }
    }

    // ---- Chargement / erreur -------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      visible: service.gestionEnCours === "lister"
      spacing: 10

      BusyIndicator {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        running: parent.visible
      }

      Label {
        Layout.fillWidth: true
        text: qsTr("Chargement des projets…")
        font: Theme.tipFont
        color: Theme.secondaryTextColor
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: blocErreurListe.implicitHeight + 20

      visible: fenetre.erreurListe !== ""

      radius: 10
      color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.14)
      border.width: 1
      border.color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.4)

      ColumnLayout {
        id: blocErreurListe

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Label {
          Layout.fillWidth: true
          text: fenetre.erreurListe
          font: Theme.tinyFont
          color: Theme.mainTextColor
          wrapMode: Text.WordWrap
        }

        QfButton {
          Layout.alignment: Qt.AlignRight
          text: qsTr("Réessayer")
          enabled: fenetre.serveurJoignable
          bgcolor: "transparent"
          color: fenetre.accent
          borderColor: fenetre.accent
          onClicked: fenetre.chargerListe()
        }
      }
    }

    Label {
      Layout.fillWidth: true
      visible: fenetre.listeChargee
      text: qsTr("%n projet(s)", "", fenetre.projetsFiltres.length) + (fenetre.projetsFiltres.length !== fenetre.projets.length ? qsTr(" sur %1").arg(fenetre.projets.length) : "")
      font: Theme.tinyFont
      color: Theme.secondaryTextColor
    }

    // ---- Les projets -----------------------------------------------------------------
    Repeater {
      model: fenetre.projetsFiltres

      delegate: Rectangle {
        id: ligneProjet

        readonly property var projet: modelData
        readonly property var droits: modelData["droits"]

        Layout.fillWidth: true
        Layout.preferredHeight: contenuProjet.implicitHeight + 16

        radius: 10
        color: souris.pressed ? Theme.controlBorderColor : Theme.controlBackgroundAlternateColor
        border.width: 1
        border.color: Theme.controlBorderColor

        RowLayout {
          id: contenuProjet

          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 12
          anchors.rightMargin: 8
          spacing: 8

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
              Layout.fillWidth: true
              text: "[" + ligneProjet.projet["pro_an"] + "]  " + ligneProjet.projet["pro_no"] + " : " + ligneProjet.projet["pro_nom"]
              font: Theme.strongTipFont
              color: Theme.mainTextColor
              elide: Text.ElideRight
            }

            Label {
              Layout.fillWidth: true
              text: fenetre.resumeProjet(ligneProjet.projet)
              font: Theme.tinyFont
              color: Theme.secondaryTextColor
              wrapMode: Text.WordWrap
            }
          }

          // Ce que l'utilisateur peut en faire, d'un coup d'œil.
          IconImage {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            source: Theme.getThemeVectorIcon(ligneProjet.droits["modifiable"] ? "ic_edit_attributes_white_24dp" : "ic_view_black_24dp")
            color: ligneProjet.droits["modifiable"] ? fenetre.accent : Theme.secondaryTextColor
            sourceSize: Qt.size(40, 40)
          }

          IconImage {
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            source: Theme.getThemeVectorIcon("ic_chevron_right_white_24dp")
            color: Theme.secondaryTextColor
            sourceSize: Qt.size(36, 36)
          }
        }

        MouseArea {
          id: souris

          anchors.fill: parent
          enabled: service.gestionEnCours === ""
          onClicked: fenetre.ouvrirProjet(ligneProjet.projet)
        }
      }
    }

    Label {
      Layout.fillWidth: true
      visible: fenetre.listeChargee && fenetre.projetsFiltres.length === 0
      text: qsTr("Aucun projet ne correspond à ces filtres.")
      font: Theme.tipFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }
  }

  // ===========================================================================
  //  VUE DÉTAIL
  // ===========================================================================
  ColumnLayout {
    Layout.fillWidth: true
    visible: fenetre.vue === "detail"
    spacing: 8

    QfButton {
      Layout.alignment: Qt.AlignLeft
      text: fenetre.modifiable && formulaire.modifie ? qsTr("← Abandonner les modifications") : qsTr("← Tous les projets")
      bgcolor: "transparent"
      color: fenetre.accent
      enabled: service.gestionEnCours !== "modifier"
      onClicked: fenetre.revenirALaListe()
    }

    // ---- Chargement du projet --------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      visible: service.gestionEnCours === "lire"
      spacing: 10

      BusyIndicator {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        running: parent.visible
      }

      Label {
        Layout.fillWidth: true
        text: qsTr("Chargement du projet…")
        font: Theme.tipFont
        color: Theme.secondaryTextColor
      }
    }

    // ---- En-tête du projet ---------------------------------------------------------
    Label {
      Layout.fillWidth: true
      visible: fenetre.projetCourant !== null
      text: fenetre.projetCourant ? fenetre.projetCourant["pro_no"] + " — " + fenetre.projetCourant["pro_nom"] : ""
      font: Theme.strongFont
      color: Theme.mainTextColor
      wrapMode: Text.WordWrap
    }

    Label {
      Layout.fillWidth: true
      visible: fenetre.projetCourant !== null
      text: fenetre.historique(fenetre.projetCourant)
      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    // ---- Droits : ce qui est modifiable, et pourquoi -------------------------------
    Rectangle {
      id: bandeauDroits

      Layout.fillWidth: true
      Layout.preferredHeight: texteDroits.implicitHeight + 20

      visible: fenetre.projetCourant !== null && fenetre.texteDroits() !== ""

      readonly property color teinte: fenetre.modifiable ? Theme.mainColor : Theme.warningColor

      radius: 10
      color: Qt.rgba(teinte.r, teinte.g, teinte.b, 0.12)
      border.width: 1
      border.color: Qt.rgba(teinte.r, teinte.g, teinte.b, 0.4)

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
          source: Theme.getThemeVectorIcon(fenetre.modifiable ? "ic_edit_attributes_white_24dp" : "ic_view_black_24dp")
          color: bandeauDroits.teinte
          sourceSize: Qt.size(40, 40)
        }

        Label {
          id: texteDroits
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          text: fenetre.texteDroits()
          font: Theme.tinyFont
          color: Theme.mainTextColor
          wrapMode: Text.WordWrap
        }
      }
    }

    // ---- Le formulaire -----------------------------------------------------------------
    FormulaireProjet {
      id: formulaire

      Layout.fillWidth: true
      visible: fenetre.projetCourant !== null

      compact: fenetre.compact
      accent: fenetre.accent
      referentiels: fenetre.referentiels
      zoneDialogue: fenetre.zoneUtile

      statuts: [
        {
          "code": "El",
          "nom": qsTr("En élaboration")
        },
        {
          "code": "Pr",
          "nom": qsTr("En production")
        },
        {
          "code": "Te",
          "nom": qsTr("Terminé")
        }
      ]

      // Rien de modifiable tant que le serveur n'a pas dit le contraire.
      champsModifiables: fenetre.modifiable ? fenetre.droitsCourants["champs_modifiables"] : []

      typesDisponibles: service.types
      typesEnCours: service.typesEnCours
      erreurTypes: fenetre.erreurTypes
      serveurJoignable: fenetre.serveurJoignable

      onSaisieModifiee: fenetre.erreurServeur = ""
      onRechargerTypes: fenetre.chargerTypes()
    }

    // ---- Ce qui manque, ou ce que le serveur a refusé -------------------------------
    Label {
      Layout.fillWidth: true
      Layout.topMargin: 8

      visible: fenetre.modifiable && formulaire.modifie && !formulaire.saisieComplete && fenetre.erreurServeur === ""
      text: qsTr("À renseigner avant d'enregistrer : %1.").arg(formulaire.champsManquants().join(qsTr(", ")))
      font: Theme.tinyFont
      color: Theme.secondaryTextColor
      wrapMode: Text.WordWrap
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.topMargin: 8
      Layout.preferredHeight: blocErreurServeur.implicitHeight + 20

      visible: fenetre.erreurServeur !== ""

      radius: 10
      color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.14)
      border.width: 1
      border.color: Qt.rgba(Theme.errorColor.r, Theme.errorColor.g, Theme.errorColor.b, 0.4)

      ColumnLayout {
        id: blocErreurServeur

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Label {
          Layout.fillWidth: true
          text: fenetre.erreurServeur
          font: Theme.tinyFont
          color: Theme.mainTextColor
          wrapMode: Text.WordWrap
        }

        // Le projet a pu changer (modifié par un autre, droits retirés) :
        // relire est toujours la bonne réponse — au prix de la saisie.
        QfButton {
          Layout.alignment: Qt.AlignRight
          visible: fenetre.projetCourant !== null
          text: qsTr("Recharger le projet")
          bgcolor: "transparent"
          color: fenetre.accent
          borderColor: fenetre.accent
          onClicked: fenetre.ouvrirProjet(fenetre.projetCourant)
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Actions
  // ---------------------------------------------------------------------------
  actions: [
    QfButton {
      visible: fenetre.vue === "detail" && fenetre.projetCourant !== null
      text: qsTr("Supprimer")
      enabled: service.gestionEnCours === ""
      bgcolor: "transparent"
      color: Theme.errorColor
      borderColor: Theme.errorColor
      onClicked: fenetre.demanderSuppression()
    },
    QfButton {
      text: qsTr("Fermer")
      bgcolor: "transparent"
      color: Theme.secondaryTextColor
      onClicked: fenetre.close()
    },
    QfButton {
      visible: fenetre.vue === "detail" && fenetre.modifiable
      text: service.gestionEnCours === "modifier" ? qsTr("Enregistrement…") : qsTr("Enregistrer")
      enabled: formulaire.modifie && formulaire.saisieComplete && fenetre.serveurJoignable && service.gestionEnCours === ""
      bgcolor: fenetre.accent
      color: fenetre.surAccent
      onClicked: fenetre.enregistrer()
    }
  ]

  // ===========================================================================
  //  Dialogues
  // ===========================================================================
  DialogueAlerte {
    id: alerte

    zoneParente: fenetre.zoneUtile
  }

  DialogueSuppressionProjet {
    id: dialogueSuppression

    zoneParente: fenetre.zoneUtile

    onConfirme: function (motDePasse) {
      service.supprimer(fenetre.projetCourant["pro_code_ident"], motDePasse);
    }
  }

  // ===========================================================================
  //  Serveur
  // ===========================================================================
  ServiceProjet {
    id: service

    session: fenetre.session

    onGestionEnCoursChanged: {
      const messages = {
        "lister": qsTr("Chargement des projets…"),
        "lire": qsTr("Chargement du projet…"),
        "modifier": qsTr("Enregistrement des modifications…"),
        "supprimer": qsTr("Suppression du projet…")
      };
      fenetre.activite = gestionEnCours !== "" ? messages[gestionEnCours] : "";
    }

    onListeRecue: function (donnees) {
      fenetre.projets = donnees.projets;
      fenetre.admin = donnees.admin === true;
      fenetre.listeChargee = true;
      fenetre.erreurListe = "";
    }

    onProjetLu: function (projet) {
      fenetre.afficherProjet(projet);
    }

    onProjetModifie: function (projet) {
      const ancienNumero = fenetre.projetCourant ? fenetre.projetCourant["pro_no"] : projet["pro_no"];

      fenetre.afficherProjet(projet);
      fenetre.remplacerDansLaListe(projet);
      if (fenetre.referentiels)
        fenetre.referentiels.majProjet(ancienNumero, projet);

      fenetre.avertir(qsTr("Projet %1 enregistré.").arg(projet["pro_no"]), "success");
    }

    onProjetSupprime: function (resultat) {
      dialogueSuppression.terminer();

      fenetre.projets = fenetre.projets.filter(function (p) {
        return p["pro_code_ident"] !== resultat["pro_code_ident"];
      });
      if (fenetre.referentiels)
        fenetre.referentiels.retirerProjet(resultat["pro_no"]);

      fenetre.projetCourant = null;
      fenetre.vue = "liste";
      fenetre.avertir(qsTr("Projet %1 supprimé.").arg(resultat["pro_no"]), "success");
    }

    onEchecGestion: function (operation, message, statut) {
      if (operation === "lister") {
        fenetre.erreurListe = message;
      } else if (operation === "lire") {
        fenetre.vue = "liste";
        fenetre.erreurListe = message;
      } else if (operation === "supprimer") {
        // Le dialogue reste ouvert : mot de passe faux, ou droits qui ont
        // changé — il le dit, et l'on peut recommencer ou annuler.
        dialogueSuppression.echouer(message);
      } else {
        fenetre.erreurServeur = message;
      }
    }

    onTypesCharges: fenetre.erreurTypes = ""

    onEchecTypes: function (message) {
      fenetre.erreurTypes = message;
    }
  }

  // ===========================================================================
  //  Fonctions
  // ===========================================================================
  function chargerListe() {
    erreurListe = "";
    service.lister();
  }

  function chargerTypes() {
    erreurTypes = "";
    service.chargerTypes();
  }

  // Le détail se relit sur le serveur : les droits et le nombre d'unités ont
  // pu changer depuis la liste, et `pro_date_maj` doit être le plus récent.
  function ouvrirProjet(projet) {
    erreurServeur = "";
    erreurListe = "";
    projetCourant = null;
    formulaire.charger(null);
    vue = "detail";
    service.lire(projet["pro_code_ident"]);
  }

  function afficherProjet(projet) {
    // Les droits d'abord : `champsModifiables` en dépend, et `charger()` fixe
    // la référence des changements.
    projetCourant = projet;
    formulaire.charger(projet);
    erreurServeur = "";

    const typesModifiables = projet["droits"]["modifiable"] && projet["droits"]["champs_modifiables"].indexOf("types_ue") !== -1;
    if (typesModifiables && service.types.length === 0 && !service.typesEnCours)
      chargerTypes();
  }

  function revenirALaListe() {
    service.oublierGestion();
    projetCourant = null;
    erreurServeur = "";
    vue = "liste";
  }

  function remplacerDansLaListe(projet) {
    projets = projets.map(function (p) {
      return p["pro_code_ident"] === projet["pro_code_ident"] ? projet : p;
    });
  }

  function enregistrer() {
    if (!projetCourant)
      return;

    const changements = formulaire.changements();
    changements["pro_date_maj"] = projetCourant["pro_date_maj"];

    erreurServeur = "";
    service.modifier(projetCourant["pro_code_ident"], changements);
  }

  // Un refus s'explique dans une alerte ; une suppression permise demande
  // confirmation et mot de passe.
  function demanderSuppression() {
    if (!projetCourant)
      return;

    if (!droitsCourants["supprimable"]) {
      alerte.afficher(qsTr("Suppression impossible"), droitsCourants["raison_suppression"], Theme.warningColor);
      return;
    }

    if (formulaire.modifie && modifiable) {
      alerte.afficher(qsTr("Modifications non enregistrées"), qsTr("Enregistrez ou abandonnez vos modifications avant de supprimer le projet."), Theme.warningColor);
      return;
    }

    dialogueSuppression.demander(projetCourant);
  }

  // ---- Textes ---------------------------------------------------------------------
  function texteDroits() {
    const d = droitsCourants;
    if (!d)
      return "";

    if (!d["modifiable"])
      return qsTr("Affichage seul. %1").arg(d["raison_modification"]);

    return d["raison_modification"];
  }

  function libelleStatut(code) {
    return libellesStatut[code] ? libellesStatut[code] : code;
  }

  function date(horodatage) {
    return horodatage ? ("" + horodatage).substring(0, 10) : "";
  }

  // La deuxième ligne d'un projet dans la liste.
  function resumeProjet(projet) {
    const parties = [];

    parties.push(projet["rad_no"] ? qsTr("Région %1").arg(projet["rad_no"]) : qsTr("Sans région"));
    parties.push(libelleStatut(projet["pro_code_statu"]));
    parties.push(qsTr("%n UE", "", projet["nb_unites"]));
    if (projet["pro_code_utili_creat"])
      parties.push(projet["droits"]["createur"] ? qsTr("créé par vous") : qsTr("créé par %1").arg(projet["pro_code_utili_creat"]));

    return parties.join("  ·  ");
  }

  // Création, dernière modification, usage.
  function historique(projet) {
    if (!projet)
      return "";

    const parties = [libelleStatut(projet["pro_code_statu"])];

    if (projet["pro_code_utili_creat"] || projet["pro_date_creat"])
      parties.push(qsTr("créé par %1 le %2").arg(projet["pro_code_utili_creat"] || "?").arg(date(projet["pro_date_creat"])));
    if (projet["pro_code_utili_maj"] || projet["pro_date_maj"])
      parties.push(qsTr("modifié par %1 le %2").arg(projet["pro_code_utili_maj"] || "?").arg(date(projet["pro_date_maj"])));
    parties.push(qsTr("utilisé par %n UE", "", projet["nb_unites"]));

    return parties.join("  ·  ");
  }
}
