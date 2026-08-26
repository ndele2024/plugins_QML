// =============================================================================
//  TableauUE — liste des unités d'échantillonnage retournées par une recherche
// =============================================================================
//  Deux rendus à partir du même modèle, choisis selon la largeur disponible :
//
//    * large  (≥ 640 px) : tableau classique, en-tête + lignes, défilement
//      horizontal si les colonnes débordent ;
//    * étroit (téléphone) : une fiche par unité, les actions en toutes lettres.
//
//  Un tableau de neuf colonnes est illisible sur un téléphone, et surtout
//  dangereux : atteindre la corbeille demanderait de faire défiler
//  horizontalement, geste propice aux suppressions accidentelles.
//
//  Le composant n'exécute aucune action : il émet un signal par ligne et laisse
//  la fenêtre appelante décider (confirmation, appel serveur, …).
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import QtQuick.Layouts

import org.qfield
import Theme

ColumnLayout {
  id: tableau

  // ---------------------------------------------------------------------------
  //  API publique
  // ---------------------------------------------------------------------------
  // Liste d'objets telle que la renvoie ServiceUE (voir son contrat).
  property var lignes: []

  property color accent: Theme.cloudColor

  signal ouvrirVerrouille(var unite)
  signal ouvrirLecture(var unite)
  signal supprimer(var unite)

  readonly property bool compact: width < 640

  spacing: 0

  // ---------------------------------------------------------------------------
  //  Largeurs des colonnes — partagées par l'en-tête et les lignes
  // ---------------------------------------------------------------------------
  readonly property real largeurCode: 150
  readonly property real largeurType: 180
  readonly property real largeurVerrou: 104
  readonly property real largeurDate: 104
  readonly property real largeurUtilisateur: 88
  readonly property real largeurActions: 148

  // Marge intérieure gauche/droite des lignes, à inclure dans la largeur
  // défilable sous peine de tronquer la dernière colonne.
  readonly property real margeLigne: 10

  readonly property real largeurTotale: largeurCode + largeurType + largeurVerrou + largeurDate + largeurUtilisateur + largeurDate + largeurActions + 2 * margeLigne

  // ===========================================================================
  //  RENDU LARGE — tableau
  // ===========================================================================
  Flickable {
    id: zoneTableau

    Layout.fillWidth: true
    Layout.preferredHeight: colonneTableau.implicitHeight

    visible: !tableau.compact

    clip: true
    contentWidth: Math.max(width, tableau.largeurTotale)
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.horizontal: ScrollBar {
      policy: ScrollBar.AsNeeded
    }

    Column {
      id: colonneTableau

      width: zoneTableau.contentWidth
      spacing: 0

      // ---- En-tête -----------------------------------------------------------
      Rectangle {
        width: parent.width
        height: 38
        color: Qt.rgba(tableau.accent.r, tableau.accent.g, tableau.accent.b, 0.12)

        Row {
          anchors.fill: parent
          anchors.leftMargin: tableau.margeLigne
          anchors.rightMargin: tableau.margeLigne

          Label {
            width: tableau.largeurCode
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Code UE")
            font: Theme.strongTipFont
            color: tableau.accent
            elide: Text.ElideRight
          }
          Label {
            width: tableau.largeurType
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Type d'UE")
            font: Theme.strongTipFont
            color: tableau.accent
            elide: Text.ElideRight
          }
          Label {
            width: tableau.largeurVerrou
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Verrou")
            font: Theme.strongTipFont
            color: tableau.accent
            elide: Text.ElideRight
          }
          Label {
            width: tableau.largeurDate
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Créée le")
            font: Theme.strongTipFont
            color: tableau.accent
            elide: Text.ElideRight
          }
          Label {
            width: tableau.largeurUtilisateur
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Par")
            font: Theme.strongTipFont
            color: tableau.accent
            elide: Text.ElideRight
          }
          Label {
            width: tableau.largeurDate
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Modifiée le")
            font: Theme.strongTipFont
            color: tableau.accent
            elide: Text.ElideRight
          }
          Label {
            width: tableau.largeurActions
            height: parent.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Actions")
            font: Theme.strongTipFont
            color: tableau.accent
            elide: Text.ElideRight
          }
        }
      }

      // ---- Lignes ------------------------------------------------------------
      Repeater {
        model: tableau.lignes

        delegate: Rectangle {
          id: ligne

          readonly property var unite: modelData
          readonly property bool verrouillee: unite["une_ind_verro"] === "O"

          width: colonneTableau.width
          height: 52
          color: index % 2 === 0 ? "transparent" : Theme.controlBackgroundAlternateColor

          Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.controlBorderColor
            opacity: 0.6
          }

          Row {
            anchors.fill: parent
            anchors.leftMargin: tableau.margeLigne
            anchors.rightMargin: tableau.margeLigne

            Label {
              width: tableau.largeurCode
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: ligne.unite["une_code_ident"]
              font: Theme.strongFont
              color: Theme.mainTextColor
              elide: Text.ElideRight
            }

            Label {
              width: tableau.largeurType
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: ligne.unite["tue_nom"]
              font: Theme.tipFont
              color: Theme.mainTextColor
              elide: Text.ElideRight
            }

            Item {
              width: tableau.largeurVerrou
              height: parent.height

              EtiquetteVerrou {
                anchors.verticalCenter: parent.verticalCenter
                verrouillee: ligne.verrouillee
                detenteur: ligne.unite["une_nom_propr_verro"]
              }
            }

            Label {
              width: tableau.largeurDate
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: tableau.formaterDate(ligne.unite["une_date_creat"])
              font: Theme.tipFont
              color: Theme.secondaryTextColor
              elide: Text.ElideRight
            }

            Label {
              width: tableau.largeurUtilisateur
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: ligne.unite["une_code_utili_creat"]
              font: Theme.tipFont
              color: Theme.secondaryTextColor
              elide: Text.ElideRight
            }

            Label {
              width: tableau.largeurDate
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: tableau.formaterDate(ligne.unite["une_date_maj"])
              font: Theme.tipFont
              color: Theme.secondaryTextColor
              elide: Text.ElideRight
            }

            Row {
              width: tableau.largeurActions
              height: parent.height
              spacing: 4

              QfToolButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                round: true
                bgcolor: "transparent"
                enabled: !ligne.verrouillee
                opacity: enabled ? 1 : 0.35
                iconSource: Theme.getThemeVectorIcon("ic_lock_white_24dp")
                iconColor: tableau.accent
                ToolTip.visible: hovered
                ToolTip.text: ligne.verrouillee ? qsTr("Déjà verrouillée par %1").arg(ligne.unite["une_nom_propr_verro"]) : qsTr("Ouvrir et verrouiller")
                onClicked: tableau.ouvrirVerrouille(ligne.unite)
              }

              QfToolButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                round: true
                bgcolor: "transparent"
                iconSource: Theme.getThemeVectorIcon("ic_view_black_24dp")
                iconColor: Theme.mainTextColor
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Ouvrir sans verrouiller")
                onClicked: tableau.ouvrirLecture(ligne.unite)
              }

              QfToolButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                round: true
                bgcolor: "transparent"
                enabled: !ligne.verrouillee
                opacity: enabled ? 1 : 0.35
                iconSource: Theme.getThemeVectorIcon("ic_delete_forever_white_24dp")
                iconColor: Theme.errorColor
                ToolTip.visible: hovered
                ToolTip.text: ligne.verrouillee ? qsTr("Impossible : unité verrouillée") : qsTr("Supprimer")
                onClicked: tableau.supprimer(ligne.unite)
              }
            }
          }
        }
      }
    }
  }

  // ===========================================================================
  //  RENDU ÉTROIT — une fiche par unité
  // ===========================================================================
  Repeater {
    model: tableau.compact ? tableau.lignes : []

    delegate: Rectangle {
      id: fiche

      readonly property var unite: modelData
      readonly property bool verrouillee: unite["une_ind_verro"] === "O"

      Layout.fillWidth: true
      Layout.bottomMargin: 8

      implicitHeight: contenuFiche.implicitHeight + 24
      radius: 12
      color: Theme.controlBackgroundAlternateColor
      border.width: 1
      border.color: fiche.verrouillee ? Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.45) : Theme.controlBorderColor

      ColumnLayout {
        id: contenuFiche

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Label {
            Layout.fillWidth: true
            text: fiche.unite["une_code_ident"]
            font: Theme.strongFont
            color: Theme.mainTextColor
            elide: Text.ElideRight
          }

          EtiquetteVerrou {
            verrouillee: fiche.verrouillee
            detenteur: fiche.unite["une_nom_propr_verro"]
          }
        }

        Label {
          Layout.fillWidth: true
          text: fiche.unite["tue_nom"]
          font: Theme.tipFont
          color: Theme.mainTextColor
          wrapMode: Text.WordWrap
        }

        Label {
          Layout.fillWidth: true
          font: Theme.tinyFont
          color: Theme.secondaryTextColor
          wrapMode: Text.WordWrap
          text: qsTr("Créée le %1 par %2").arg(tableau.formaterDate(fiche.unite["une_date_creat"])).arg(fiche.unite["une_code_utili_creat"]) + "\n" + qsTr("Modifiée le %1 par %2").arg(tableau.formaterDate(fiche.unite["une_date_maj"])).arg(fiche.unite["une_code_utili_maj"])
        }

        Flow {
          Layout.fillWidth: true
          Layout.topMargin: 4
          spacing: 6

          QfButton {
            text: qsTr("Verrouiller")
            enabled: !fiche.verrouillee
            bgcolor: fiche.verrouillee ? "transparent" : tableau.accent
            color: fiche.verrouillee ? Theme.mainTextDisabledColor : "#ffffff"
            icon.source: Theme.getThemeVectorIcon("ic_lock_white_24dp")
            onClicked: tableau.ouvrirVerrouille(fiche.unite)
          }

          QfButton {
            text: qsTr("Consulter")
            bgcolor: "transparent"
            color: Theme.mainTextColor
            borderColor: Theme.controlBorderColor
            icon.source: Theme.getThemeVectorIcon("ic_view_black_24dp")
            onClicked: tableau.ouvrirLecture(fiche.unite)
          }

          QfToolButton {
            width: 44
            height: 44
            round: true
            bgcolor: "transparent"
            enabled: !fiche.verrouillee
            opacity: enabled ? 1 : 0.35
            iconSource: Theme.getThemeVectorIcon("ic_delete_forever_white_24dp")
            iconColor: Theme.errorColor
            onClicked: tableau.supprimer(fiche.unite)
          }
        }
      }
    }
  }

  // ===========================================================================
  //  Fonctions
  // ===========================================================================
  // « 2009-10-21T14:52:56Z » → « 2009-10-21 ». Les horodatages arrivent en
  // ISO 8601 ; on n'affiche que la date, la partie horaire n'apportant rien
  // dans un tableau de suivi.
  function formaterDate(horodatage) {
    if (!horodatage)
      return "—";
    const texte = "" + horodatage;
    const separateur = texte.indexOf("T");
    return separateur > 0 ? texte.substring(0, separateur) : texte;
  }
}
