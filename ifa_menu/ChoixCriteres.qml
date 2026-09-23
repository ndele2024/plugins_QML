// =============================================================================
//  ChoixCriteres — sélection de plusieurs critères de filtrage
// =============================================================================
//  Une rangée de pastilles que l'on coche indépendamment les unes des autres.
//  Chaque pastille cochée ajoute un critère, et les critères se **croisent** :
//  une unité doit les satisfaire tous. C'est ce que fait le serveur (voir
//  `filtres.predicats()` dans l'application Django), et c'est ce que le libellé
//  d'aide sous les pastilles rappelle au technicien.
//
//  ---------------------------------------------------------------------------
//  POURQUOI PAS `QfToggleButtonGroup`
//  ---------------------------------------------------------------------------
//  Le composant de QField ne retient qu'un choix à la fois — c'est précisément
//  ce dont les deux fenêtres se départissent ici. Un groupe de `CheckBox`
//  aurait fait l'affaire, mais il prend une ligne par case : cinq critères
//  occuperaient tout l'écran d'un téléphone avant même que le premier champ de
//  saisie n'apparaisse. Les pastilles se replient d'elles-mêmes sur plusieurs
//  rangs (`Flow`) et tiennent en deux lignes.
//
//  ---------------------------------------------------------------------------
//  CONTRAT
//  ---------------------------------------------------------------------------
//    criteres  : [{ cle: "region", libelle: "Région" }, …] — l'ordre affiché
//    selection : ["region", "bassin"] — les clés cochées, dans l'ordre de
//                `criteres` et non dans celui des clics : une liste qui se
//                réordonne sous les doigts rendrait le résumé du filtre
//                illisible d'une recherche à l'autre.
//
//  Le composant ne connaît ni les champs de saisie ni le serveur : il coche, et
//  signale. C'est la fenêtre qui décide de ce qu'une pastille cochée affiche et
//  de ce qu'elle envoie.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl

import org.qfield
import Theme

Flow {
  id: choix

  // ---------------------------------------------------------------------------
  //  API publique
  // ---------------------------------------------------------------------------
  property var criteres: []
  property var selection: []

  property color accent: Theme.mainColor

  signal selectionChangee(var selection)

  spacing: 8

  // Vrai si cette clé fait partie de la sélection.
  function estActif(cle) {
    return selection.indexOf(cle) !== -1;
  }

  // Coche ou décoche une pastille, puis recompose la sélection dans l'ordre
  // d'affichage. Reconstruire la liste plutôt que d'y pousser la clé garde cet
  // ordre stable, quel que soit l'ordre des clics.
  //
  // La nouvelle sélection est seulement signalée, jamais écrite dans
  // `selection` : c'est la fenêtre qui la détient, et le composant la lit par
  // liaison. S'assigner la valeur ici romprait cette liaison — le composant
  // cesserait alors de suivre la fenêtre, et le premier `reinitialiser()`
  // venu laisserait les pastilles cochées.
  function basculer(cle) {
    const veutActiver = !estActif(cle);
    const retenues = [];

    for (let i = 0; i < criteres.length; ++i) {
      const candidate = criteres[i]["cle"];

      if (candidate === cle) {
        if (veutActiver)
          retenues.push(candidate);
        continue;
      }

      if (estActif(candidate))
        retenues.push(candidate);
    }

    selectionChangee(retenues);
  }

  // ---------------------------------------------------------------------------
  //  Pastilles
  // ---------------------------------------------------------------------------
  Repeater {
    model: choix.criteres

    delegate: Rectangle {
      id: pastille

      readonly property string cle: modelData["cle"]

      // La lecture de `choix.selection` est faite ici, dans la liaison
      // elle-même : passer par `estActif()` marcherait aussi, mais la
      // dépendance serait invisible à la relecture.
      readonly property bool actif: choix.selection.indexOf(cle) !== -1

      width: contenu.implicitWidth + 24
      height: 36
      radius: 18

      color: actif ? Qt.rgba(choix.accent.r, choix.accent.g, choix.accent.b, 0.16) : Theme.controlBackgroundAlternateColor
      border.width: 1
      border.color: actif ? choix.accent : Theme.controlBorderColor

      Row {
        id: contenu

        anchors.centerIn: parent
        spacing: 6

        // La coche n'occupe de la place que lorsqu'elle est là : une pastille
        // qui s'élargit au clic se voit, et c'est le retour recherché.
        IconImage {
          anchors.verticalCenter: parent.verticalCenter
          width: pastille.actif ? 16 : 0
          height: 16
          visible: pastille.actif
          source: Theme.getThemeVectorIcon("ic_check_white_24dp")
          color: choix.accent
          sourceSize: Qt.size(32, 32)
        }

        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: modelData["libelle"]
          font: pastille.actif ? Theme.strongTipFont : Theme.tipFont
          color: pastille.actif ? choix.accent : Theme.secondaryTextColor
        }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: choix.basculer(pastille.cle)
      }
    }
  }
}
