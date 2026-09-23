// =============================================================================
//  FenetreValidation — rapport de validation IFE du projet ouvert
// =============================================================================
//  Ce que le serveur a trouvé dans les données synchronisées : le verdict, les
//  compteurs, et la liste des anomalies. Le rapport lui-même est tenu par
//  `ServiceValidation`, qui vit dans `main.qml` — il doit guetter les push même
//  quand aucune fenêtre n'est ouverte.
//
//  La fenêtre ne fait donc qu'afficher, et proposer un rafraîchissement. Elle
//  dit surtout **ce qu'elle ne sait pas** : un rapport qui ne reflète plus les
//  données est plus dangereux qu'une absence de rapport, puisqu'il donne un
//  verdict rassurant sur un état dépassé. D'où le bandeau, et le verdict grisé
//  dès que l'affichage n'engage plus rien.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

IfaPopup {
  id: fenetre

  titre: qsTr("Validation")
  soustitre: qsTr("Rapport du projet ouvert")
  icone: "ic_check_white_24dp"
  accent: Theme.mainColor
  largeurMax: 640

  // Filtre de sévérité de la liste des anomalies.
  property string filtreSeverite: "tout"

  readonly property var rapport: validation ? validation.rapport : null
  readonly property bool pret: validation ? validation.rapportPret : false

  readonly property color couleurVerdict: {
    if (!pret || !rapport)
      return Theme.secondaryTextColor;
    return rapport.is_valid ? Theme.goodColor : Theme.errorColor;
  }

  readonly property var anomalies: {
    if (!rapport || !rapport.issues)
      return [];
    if (filtreSeverite === "tout")
      return rapport.issues;
    return rapport.issues.filter(function (anomalie) {
      return anomalie.severity === fenetre.filtreSeverite;
    });
  }

  //  Le bandeau épinglé de l'IfaPopup — roue qui tourne et texte d'étape —
  //  apparaît dès que `activite` n'est pas vide. Il est réservé à l'attente du
  //  **serveur** : des modifications non synchronisées n'en sont pas une, et le
  //  bandeau d'avertissement ci-dessous le dit déjà mieux.
  activite: attendServeur && validation.diagnostic !== "" ? validation.diagnostic : (attendServeur ? qsTr("Interrogation du serveur…") : "")

  // `attenteVisible` et non `enAttenteServeur` : contre un serveur local, la
  // réponse revient en quelques dizaines de millisecondes, et le bandeau
  // n'aurait pas le temps d'être vu. Voir `ServiceValidation`.
  readonly property bool attendServeur: validation !== null && validation.attenteVisible

  // ---------------------------------------------------------------------------
  //  Service absent : la fenêtre reste ouvrable et le dit
  // ---------------------------------------------------------------------------
  Label {
    Layout.fillWidth: true
    visible: !fenetre.validation
    text: qsTr("Le suivi de la validation n'est pas disponible.")
    font: Theme.tipFont
    color: Theme.secondaryTextColor
    wrapMode: Text.WordWrap
  }

  // ---------------------------------------------------------------------------
  //  Bandeau : le rapport ne reflète peut-être plus les données
  // ---------------------------------------------------------------------------
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: texteBandeau.implicitHeight + 20

    visible: fenetre.validation !== null && !fenetre.pret

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
        id: texteBandeau

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter

        font: Theme.tinyFont
        color: Theme.mainTextColor
        wrapMode: Text.WordWrap

        text: {
          if (!fenetre.validation)
            return "";
          if (fenetre.validation.deltasEnAttente)
            return qsTr("Des modifications ne sont pas encore synchronisées : ce rapport ne les couvre pas.");
          if (fenetre.validation.attenteRapport)
            return qsTr("Synchronisation acceptée — le serveur valide les données.");
          if (fenetre.validation.perime)
            return qsTr("Ce rapport n'est peut-être plus à jour. Rafraîchissez pour le vérifier.");
          return qsTr("Aucun rapport n'a encore été chargé pour ce projet.");
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Verdict
  // ---------------------------------------------------------------------------
  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 64
    Layout.topMargin: 4

    visible: fenetre.rapport !== null

    radius: 12
    color: Theme.controlBackgroundAlternateColor
    border.width: 1
    border.color: Theme.controlBorderColor

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 12

      Rectangle {
        Layout.preferredWidth: 6
        Layout.preferredHeight: 40
        radius: 3
        color: fenetre.couleurVerdict
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Label {
          Layout.fillWidth: true
          text: {
            if (!fenetre.rapport)
              return "";
            if (!fenetre.pret)
              return qsTr("Verdict non garanti");
            return fenetre.rapport.is_valid ? qsTr("Données valides") : qsTr("Données invalides");
          }
          font: Theme.strongTipFont
          color: fenetre.couleurVerdict
          elide: Text.ElideRight
        }

        Label {
          Layout.fillWidth: true
          text: fenetre.rapport && fenetre.rapport.genere_le ? qsTr("Généré le %1").arg(("" + fenetre.rapport.genere_le).replace("T", " ").replace("Z", " UTC")) : ""
          font: Theme.tinyFont
          color: Theme.secondaryTextColor
          elide: Text.ElideRight
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Compteurs
  // ---------------------------------------------------------------------------
  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: 4
    spacing: 8

    visible: fenetre.rapport !== null

    Repeater {
      model: fenetre.rapport ? [
        {
          "libelle": qsTr("Erreurs"),
          "nombre": fenetre.rapport.error_count !== undefined ? fenetre.rapport.error_count : 0,
          "couleur": Theme.errorColor
        },
        {
          "libelle": qsTr("Avertissements"),
          "nombre": fenetre.rapport.warning_count !== undefined ? fenetre.rapport.warning_count : 0,
          "couleur": Theme.warningColor
        },
        {
          "libelle": qsTr("Couches"),
          "nombre": (fenetre.rapport.layers_processed || []).length,
          "couleur": Theme.mainColor
        }
      ] : []

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 58

        radius: 10
        color: Qt.rgba(modelData["couleur"].r, modelData["couleur"].g, modelData["couleur"].b, 0.12)

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 0

          Label {
            Layout.alignment: Qt.AlignHCenter
            text: "" + modelData["nombre"]
            font: Theme.strongTitleFont
            color: modelData["couleur"]
          }

          Label {
            Layout.alignment: Qt.AlignHCenter
            text: modelData["libelle"]
            font: Theme.tinyFont
            color: modelData["couleur"]
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Filtre de sévérité
  // ---------------------------------------------------------------------------
  QfToggleButtonGroup {
    id: choixSeverite

    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.minimumHeight: choixSeverite.height

    visible: fenetre.rapport !== null && fenetre.rapport.issues !== undefined && fenetre.rapport.issues.length > 0

    selectedIndex: 0
    model: [qsTr("Tout"), qsTr("Erreurs"), qsTr("Avertissements")]

    readonly property var severites: ["tout", "error", "warning"]

    onItemSelected: function (index, modelData) {
      fenetre.filtreSeverite = choixSeverite.severites[index];
    }
  }

  // ---------------------------------------------------------------------------
  //  Anomalies
  // ---------------------------------------------------------------------------
  //  Une colonne de fiches plutôt qu'une `ListView` : le contenu de l'IfaPopup
  //  est déjà dans une zone défilante, et deux défilements imbriqués se
  //  disputent le geste du doigt.
  Label {
    Layout.fillWidth: true
    Layout.topMargin: 8

    visible: fenetre.rapport !== null && fenetre.anomalies.length === 0
    text: fenetre.filtreSeverite === "tout" ? qsTr("Aucune anomalie.") : qsTr("Aucune anomalie pour ce filtre.")
    font: Theme.tipFont
    color: Theme.secondaryTextColor
    horizontalAlignment: Text.AlignHCenter
  }

  Repeater {
    model: fenetre.anomalies

    Rectangle {
      id: fiche

      readonly property bool grave: modelData["severity"] === "error"
      readonly property color teinte: grave ? Theme.errorColor : Theme.warningColor

      Layout.fillWidth: true
      Layout.topMargin: 6
      Layout.preferredHeight: colonneAnomalie.implicitHeight + 20

      radius: 10
      color: Qt.rgba(teinte.r, teinte.g, teinte.b, 0.08)
      border.width: 1
      border.color: Qt.rgba(teinte.r, teinte.g, teinte.b, 0.35)

      ColumnLayout {
        id: colonneAnomalie

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 4

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          IconImage {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            source: Theme.getThemeVectorIcon(fiche.grave ? "ic_dissatisfied_white_24dp" : "ic_alert_black_24dp")
            color: fiche.teinte
            sourceSize: Qt.size(32, 32)
          }

          Label {
            Layout.fillWidth: true
            text: "[" + (modelData["layer"] ? modelData["layer"] : "—") + "] " + (modelData["code"] ? modelData["code"] : "")
            font: Theme.strongTipFont
            color: fiche.teinte
            elide: Text.ElideRight
          }
        }

        Label {
          Layout.fillWidth: true
          text: modelData["message"] ? modelData["message"] : ""
          font: Theme.tipFont
          color: Theme.mainTextColor
          wrapMode: Text.WordWrap
        }

        Label {
          Layout.fillWidth: true
          visible: modelData["fields"] !== undefined && modelData["fields"] !== null && modelData["fields"].length > 0
          text: qsTr("Champs : %1").arg((modelData["fields"] || []).join(", "))
          font: Theme.tinyFont
          color: Theme.secondaryTextColor
          wrapMode: Text.WordWrap
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  //  Diagnostic — ce que le service sait, quand il n'y a pas de rapport
  // ---------------------------------------------------------------------------
  Label {
    Layout.fillWidth: true
    Layout.topMargin: 10

    visible: fenetre.validation !== null && fenetre.rapport === null
    text: fenetre.validation ? fenetre.validation.diagnostic : ""
    font: Theme.tipFont
    color: Theme.secondaryTextColor
    wrapMode: Text.WordWrap
    horizontalAlignment: Text.AlignHCenter
  }

  // ---------------------------------------------------------------------------
  //  Actions
  // ---------------------------------------------------------------------------
  actions: [
    QfButton {
      // Le libellé change aussi : un bouton simplement grisé se lit comme
      // « indisponible », pas comme « en cours ».
      text: fenetre.attendServeur ? qsTr("Interrogation…") : qsTr("Rafraîchir")
      enabled: fenetre.validation !== null && !fenetre.attendServeur
      bgcolor: "transparent"
      color: fenetre.accent
      borderColor: Theme.controlBorderColor
      onClicked: fenetre.validation.rafraichir()
    },
    QfButton {
      text: qsTr("Fermer")
      bgcolor: fenetre.accent
      color: fenetre.surAccent
      onClicked: fenetre.close()
    }
  ]
}
