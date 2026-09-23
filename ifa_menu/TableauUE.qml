// =============================================================================
//  TableauUE — liste des unités d'échantillonnage retournées par une recherche
// =============================================================================
//  Deux rendus à partir du même modèle, choisis selon la largeur disponible :
//
//    * large  (≥ 640 px) : tableau classique, en-tête + lignes, défilement
//      horizontal si les colonnes débordent ;
//    * étroit (téléphone) : une fiche par unité, les actions en toutes lettres.
//
//  Un tableau de huit colonnes est illisible sur un téléphone, et surtout
//  dangereux : atteindre la corbeille demanderait de faire défiler
//  horizontalement, geste propice aux suppressions accidentelles.
//
//  ---------------------------------------------------------------------------
//  QUI TIENT L'UNITÉ, ET QUI L'A TOUCHÉE EN DERNIER
//  ---------------------------------------------------------------------------
//  Deux questions voisines, deux colonnes distinctes, et il vaut mieux ne pas
//  les confondre :
//
//    * **le détenteur du verrou** (`une_nom_propr_verro`) est celui à qui il
//      faut s'adresser *maintenant* pour obtenir l'unité. Son nom est écrit
//      sous la pastille de verrou, en toutes lettres : il était auparavant en
//      infobulle, ce qui ne s'atteint pas au doigt — sur une tablette de
//      terrain, l'information n'existait donc pas ;
//    * **l'auteur de la dernière mise à jour** (`une_code_utili_maj`) est celui
//      qui a écrit les dernières données. Ce n'est pas forcément le détenteur :
//      une unité rendue garde l'auteur de sa dernière saisie, et une unité
//      fraîchement verrouillée n'a pas encore été modifiée par celui qui la
//      tient.
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

  // Compte connecté. Il décide de ce que devient le bouton de verrouillage sur
  // une unité déjà tenue : un cadenas fermé et éteint si elle est à quelqu'un
  // d'autre, un cadenas ouvert et cliquable si elle est à soi.
  //
  // Vide, le bouton ne propose jamais le déverrouillage — c'est le bon repli :
  // le serveur refuserait de toute façon de lever le verrou d'un autre.
  property string utilisateur: ""

  // Unité dont l'ouverture est en cours (`une_code_ident`), ou "" si aucune.
  // Sa ligne montre une attente à la place de ses actions, et celles des autres
  // lignes se désactivent : une seule ouverture à la fois, et le technicien
  // voit sur quelle ligne il a cliqué sans avoir à remonter la liste.
  property string uniteEnCours: ""

  // Même chose pour le déverrouillage. L'aller-retour est bien plus court,
  // mais il écrit dans la base métier : il mérite le même retour.
  property string uniteDeverrouillage: ""

  readonly property bool ouvertureEnCours: uniteEnCours !== ""
  readonly property bool deverrouillageEnCours: uniteDeverrouillage !== ""

  // Un seul travail à la fois, quel qu'il soit.
  readonly property bool occupe: ouvertureEnCours || deverrouillageEnCours

  signal ouvrirVerrouille(var unite)
  signal ouvrirLecture(var unite)
  signal deverrouiller(var unite)
  signal supprimer(var unite)

  readonly property bool compact: width < 640

  spacing: 0

  // ---------------------------------------------------------------------------
  //  Largeurs des colonnes — partagées par l'en-tête et les lignes
  // ---------------------------------------------------------------------------
  readonly property real largeurCode: 150
  readonly property real largeurType: 180
  // La colonne du verrou porte deux lignes : la pastille, et le nom de son
  // détenteur en dessous. Les comptes du fonds tiennent en sept caractères,
  // mais `une_nom_propr_verro` en accepte cent : un nom plus long est élidé,
  // et l'infobulle de la pastille le donne alors en entier.
  readonly property real largeurVerrou: 132
  readonly property real largeurDate: 104
  readonly property real largeurUtilisateur: 88
  readonly property real largeurActions: 148

  // Marge intérieure gauche/droite des lignes, à inclure dans la largeur
  // défilable sous peine de tronquer la dernière colonne.
  readonly property real margeLigne: 10

  readonly property real largeurTotale: largeurCode + largeurType + largeurVerrou + largeurDate + largeurUtilisateur + largeurDate + largeurUtilisateur + largeurActions + 2 * margeLigne

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
            text: qsTr("Créée par")
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
            width: tableau.largeurUtilisateur
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: qsTr("Modifiée par")
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

          // Verrouillée, et par l'utilisateur lui-même : le seul cas où le
          // serveur acceptera de lever le verrou.
          readonly property bool tenuePourMoi: verrouillee && tableau.estMoi(unite["une_nom_propr_verro"])

          readonly property bool enCours: tableau.uniteEnCours !== "" && tableau.uniteEnCours === unite["une_code_ident"]
          readonly property bool deverrouillageEnCours: tableau.uniteDeverrouillage !== "" && tableau.uniteDeverrouillage === unite["une_code_ident"]

          readonly property bool occupee: enCours || deverrouillageEnCours

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

              Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                spacing: 1

                EtiquetteVerrou {
                  verrouillee: ligne.verrouillee
                  detenteur: ligne.unite["une_nom_propr_verro"]
                }

                // Le nom du détenteur, écrit et non survolé : c'est lui qu'il
                // faut joindre pour obtenir l'unité, et une infobulle ne
                // s'atteint pas au doigt.
                Label {
                  width: parent.width
                  visible: ligne.verrouillee
                  text: ligne.tenuePourMoi ? qsTr("par vous") : ligne.unite["une_nom_propr_verro"]
                  font: Theme.tinyFont
                  color: Theme.warningColor
                  elide: Text.ElideRight
                }
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

            Label {
              width: tableau.largeurUtilisateur
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: ligne.unite["une_code_utili_maj"]
              font: Theme.tipFont
              color: Theme.secondaryTextColor
              elide: Text.ElideRight
            }

            Row {
              width: tableau.largeurActions
              height: parent.height
              spacing: 4

              // La ligne sur laquelle un travail est en cours remplace ses
              // actions par l'attente : c'est le retour le plus proche du geste.
              Item {
                width: tableau.largeurActions
                height: parent.height
                visible: ligne.occupee

                RowLayout {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.right: parent.right
                  spacing: 8

                  BusyIndicator {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    running: ligne.occupee
                  }

                  Label {
                    Layout.fillWidth: true
                    text: ligne.enCours ? qsTr("Ouverture…") : qsTr("Déverrouillage…")
                    font: Theme.tipFont
                    color: tableau.accent
                    elide: Text.ElideRight
                  }
                }
              }

              // Un bouton, trois états. Le cadenas ferme l'unité quand elle
              // est libre, s'ouvre quand elle est à soi, et reste fermé et
              // éteint quand elle est à quelqu'un d'autre.
              QfToolButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                round: true
                visible: !ligne.occupee
                bgcolor: "transparent"
                enabled: (ligne.tenuePourMoi || !ligne.verrouillee) && !tableau.occupe
                opacity: enabled ? 1 : 0.35
                iconSource: Theme.getThemeVectorIcon(ligne.tenuePourMoi ? "ic_lock_open_white_24dp" : "ic_lock_white_24dp")
                iconColor: ligne.tenuePourMoi ? Theme.warningColor : tableau.accent
                ToolTip.visible: hovered
                ToolTip.text: tableau.infobulleVerrou(ligne.unite, ligne.verrouillee, ligne.tenuePourMoi)
                onClicked: {
                  if (ligne.tenuePourMoi)
                    tableau.deverrouiller(ligne.unite);
                  else
                    tableau.ouvrirVerrouille(ligne.unite);
                }
              }

              QfToolButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                height: 42
                round: true
                visible: !ligne.occupee
                bgcolor: "transparent"
                enabled: !tableau.occupe
                opacity: enabled ? 1 : 0.35
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
                visible: !ligne.occupee
                bgcolor: "transparent"
                enabled: !ligne.verrouillee && !tableau.occupe
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
      readonly property bool tenuePourMoi: verrouillee && tableau.estMoi(unite["une_nom_propr_verro"])

      readonly property bool enCours: tableau.uniteEnCours !== "" && tableau.uniteEnCours === unite["une_code_ident"]
      readonly property bool deverrouillageEnCours: tableau.uniteDeverrouillage !== "" && tableau.uniteDeverrouillage === unite["une_code_ident"]

      readonly property bool occupee: enCours || deverrouillageEnCours

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

        // Comme dans le tableau large : le détenteur est écrit, pas survolé.
        Label {
          Layout.fillWidth: true
          visible: fiche.verrouillee
          text: fiche.tenuePourMoi ? qsTr("Verrouillée par vous") : qsTr("Verrouillée par %1").arg(fiche.unite["une_nom_propr_verro"])
          font: Theme.strongTipFont
          color: Theme.warningColor
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

          RowLayout {
            visible: fiche.occupee
            spacing: 8

            BusyIndicator {
              Layout.preferredWidth: 22
              Layout.preferredHeight: 22
              running: fiche.occupee
            }

            Label {
              text: fiche.enCours ? qsTr("Ouverture en cours…") : qsTr("Déverrouillage en cours…")
              font: Theme.tipFont
              color: tableau.accent
            }
          }

          // Le même bouton que dans le tableau large, en toutes lettres :
          // sur un téléphone, un cadenas seul ne dit pas s'il ferme ou ouvre.
          QfButton {
            readonly property bool actif: (fiche.tenuePourMoi || !fiche.verrouillee) && !tableau.occupe

            visible: !fiche.occupee
            text: fiche.tenuePourMoi ? qsTr("Déverrouiller") : qsTr("Verrouiller")
            enabled: actif
            bgcolor: !actif ? "transparent" : (fiche.tenuePourMoi ? Theme.warningColor : tableau.accent)
            color: !actif ? Theme.mainTextDisabledColor : "#ffffff"
            icon.source: Theme.getThemeVectorIcon(fiche.tenuePourMoi ? "ic_lock_open_white_24dp" : "ic_lock_white_24dp")
            onClicked: {
              if (fiche.tenuePourMoi)
                tableau.deverrouiller(fiche.unite);
              else
                tableau.ouvrirVerrouille(fiche.unite);
            }
          }

          QfButton {
            visible: !fiche.occupee
            text: qsTr("Consulter")
            enabled: !tableau.occupe
            bgcolor: "transparent"
            color: tableau.occupe ? Theme.mainTextDisabledColor : Theme.mainTextColor
            borderColor: Theme.controlBorderColor
            icon.source: Theme.getThemeVectorIcon("ic_view_black_24dp")
            onClicked: tableau.ouvrirLecture(fiche.unite)
          }

          QfToolButton {
            width: 44
            height: 44
            round: true
            visible: !fiche.occupee
            bgcolor: "transparent"
            enabled: !fiche.verrouillee && !tableau.occupe
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
  // Le détenteur du verrou est-il l'utilisateur connecté ?
  //
  // La comparaison est **exacte**, et tronquée à 100 caractères comme l'est la
  // colonne `une_nom_propr_verro` : c'est mot pour mot la condition du `UPDATE`
  // que le serveur exécutera. Un rapprochement plus indulgent — insensible à la
  // casse, disons — afficherait un bouton que le serveur refuserait ensuite.
  function estMoi(detenteur) {
    if (utilisateur === "" || !detenteur)
      return false;

    return ("" + detenteur) === utilisateur.substring(0, 100);
  }

  function infobulleVerrou(unite, verrouillee, tenuePourMoi) {
    if (tenuePourMoi)
      return qsTr("Verrouillée par vous — déverrouiller");

    if (verrouillee)
      return qsTr("Déjà verrouillée par %1").arg(unite["une_nom_propr_verro"]);

    return qsTr("Ouvrir et verrouiller");
  }

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
