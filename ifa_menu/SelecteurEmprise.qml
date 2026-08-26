// =============================================================================
//  SelecteurEmprise — tracé d'une emprise polygonale sur la carte QField
// =============================================================================
//  Équivalent QField de l'outil `PolygonDrawTool` de `extract_ipe_subset.py` :
//  l'utilisateur délimite une zone, et l'on en récupère le WKT qui servira de
//  filtre spatial pour les données embarquées dans les GeoPackage.
//
//  ---------------------------------------------------------------------------
//  POURQUOI UNE CROIX PLUTÔT QUE DES CLICS SUR LA CARTE
//  ---------------------------------------------------------------------------
//  Un plugin ne peut pas s'insérer dans la chaîne d'événements tactiles de la
//  carte : poser un calque transparent pour capter les clics bloquerait le
//  déplacement et le zoom. On reprend donc la méthode native de QField pour
//  numériser sans GPS : une croix fixe au centre, la carte se déplace dessous,
//  et un bouton confirme chaque sommet. C'est aussi la méthode la plus fiable
//  avec des gants.
//
//  Un raccourci « emprise visible » convertit directement les quatre coins de
//  l'écran en rectangle, pour les cas où un cadrage grossier suffit.
//
//  ---------------------------------------------------------------------------
//  UTILISATION
//  ---------------------------------------------------------------------------
//    SelecteurEmprise {
//      id: selecteur
//      onValide: function (wkt, bbox, nombreSommets) { … }
//      onAnnule: { … }
//    }
//
//    // la fenêtre appelante doit se fermer pour libérer la carte :
//    fenetre.close();
//    selecteur.demarrer();
//
//  Le WKT est produit en EPSG:4326, comme l'emprise attendue par QFieldCloud.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

import org.qfield
import org.qgis
import Theme

Item {
  id: selecteur

  // ---------------------------------------------------------------------------
  //  API publique
  // ---------------------------------------------------------------------------
  property color accent: Theme.cloudColor

  // Sommets confirmés, en CRS de la carte (liste de QgsPoint).
  property var sommets: []

  readonly property int nombreSommets: sommets.length
  readonly property bool empriseValide: nombreSommets >= 3

  // wkt   : POLYGON((...)) en EPSG:4326
  // bbox  : [xmin, ymin, xmax, ymax] en EPSG:4326
  signal valide(string wkt, var bbox, int nombreSommets)
  signal annule

  // ---------------------------------------------------------------------------
  //  Accès à la carte
  // ---------------------------------------------------------------------------
  // `mapCanvasContainer` est le conteneur dans lequel QField place ses propres
  // rubberbands ; la carte le remplit exactement (`anchors.fill: parent`), donc
  // les coordonnées écran de cet Item et celles de la carte coïncident.
  readonly property var carte: iface.mapCanvas()
  readonly property var conteneurCarte: iface.findItemByObjectName("mapCanvasContainer")

  // Le rattachement à la carte n'a lieu que pendant le tracé, puis il est
  // défait. Sans ce retour au parent d'origine, l'objet resterait rattaché au
  // conteneur de la carte et survivrait à la destruction de la fenêtre qui l'a
  // créé — laissant un calque fantôme au-dessus de la carte.
  property Item parentInitial: null

  Component.onCompleted: parentInitial = parent

  width: parent ? parent.width : 0
  height: parent ? parent.height : 0
  visible: false

  // ---------------------------------------------------------------------------
  //  Projection des sommets à l'écran
  // ---------------------------------------------------------------------------
  // La lecture de `visibleExtent` est volontaire : elle crée la dépendance qui
  // fait recalculer le tracé à chaque déplacement ou zoom de la carte.
  readonly property var cheminEcran: {
    if (!carte || !visible)
      return [];

    const _extent = carte.mapSettings.visibleExtent;
    const points = [];
    for (let i = 0; i < sommets.length; ++i) {
      points.push(carte.mapSettings.coordinateToScreen(sommets[i]));
    }
    return points;
  }

  // Tracé affiché : sommets confirmés + segment élastique vers la croix.
  readonly property var cheminApercu: {
    const points = cheminEcran.slice();
    if (points.length > 0) {
      points.push(Qt.point(selecteur.width / 2, selecteur.height / 2));
      points.push(points[0]);
    }
    return points;
  }

  // ---------------------------------------------------------------------------
  //  Tracé du polygone
  // ---------------------------------------------------------------------------
  Shape {
    anchors.fill: parent
    visible: selecteur.cheminApercu.length > 1

    // Contour sombre, pour rester lisible sur une orthophoto claire.
    ShapePath {
      strokeColor: "#40000000"
      strokeWidth: 5
      fillColor: "transparent"
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap

      PathPolyline {
        path: selecteur.cheminApercu
      }
    }

    ShapePath {
      strokeColor: selecteur.accent
      strokeWidth: 2.5
      fillColor: selecteur.nombreSommets >= 2 ? Qt.rgba(selecteur.accent.r, selecteur.accent.g, selecteur.accent.b, 0.20) : "transparent"
      joinStyle: ShapePath.RoundJoin
      capStyle: ShapePath.RoundCap

      PathPolyline {
        path: selecteur.cheminApercu
      }
    }
  }

  // Marqueurs des sommets confirmés
  Repeater {
    model: selecteur.cheminEcran

    delegate: Rectangle {
      width: 12
      height: 12
      radius: 6
      x: modelData.x - 6
      y: modelData.y - 6
      color: selecteur.accent
      border.width: 2
      border.color: "#ffffff"
    }
  }

  // ---------------------------------------------------------------------------
  //  Croix de visée, au centre exact de la carte
  // ---------------------------------------------------------------------------
  Item {
    id: croix

    anchors.centerIn: parent
    width: 48
    height: 48

    Rectangle {
      anchors.centerIn: parent
      width: 2
      height: parent.height
      color: "#ffffff"
      opacity: 0.9
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width
      height: 2
      color: "#ffffff"
      opacity: 0.9
    }

    Rectangle {
      anchors.centerIn: parent
      width: 3
      height: parent.height - 8
      color: selecteur.accent
    }

    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 8
      height: 3
      color: selecteur.accent
    }

    Rectangle {
      anchors.centerIn: parent
      width: 16
      height: 16
      radius: 8
      color: "transparent"
      border.width: 2
      border.color: "#ffffff"
    }
  }

  // ---------------------------------------------------------------------------
  //  Bandeau d'aide, en haut
  // ---------------------------------------------------------------------------
  Rectangle {
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 12

    width: Math.min(parent.width - 24, texteAide.implicitWidth + 28)
    height: texteAide.implicitHeight + 16
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.72)

    Label {
      id: texteAide

      anchors.centerIn: parent
      width: parent.width - 28

      horizontalAlignment: Text.AlignHCenter
      font: Theme.tinyFont
      color: "#ffffff"
      wrapMode: Text.WordWrap

      text: selecteur.nombreSommets === 0 ? qsTr("Déplacez la carte pour viser, puis « Ajouter »") : qsTr("%n sommet(s) — 3 minimum pour terminer", "", selecteur.nombreSommets)
    }
  }

  // ---------------------------------------------------------------------------
  //  Barre d'actions, en bas
  // ---------------------------------------------------------------------------
  Rectangle {
    id: barreActions

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 16

    width: Math.min(parent.width - 20, 460)
    height: dispositionActions.implicitHeight + 20
    radius: 14
    color: Theme.mainBackgroundColor
    border.width: 1
    border.color: Theme.controlBorderColor

    Flow {
      id: dispositionActions

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 10
      anchors.rightMargin: 10
      spacing: 6

      QfButton {
        text: qsTr("Emprise visible")
        bgcolor: "transparent"
        color: Theme.mainTextColor
        borderColor: Theme.controlBorderColor
        onClicked: selecteur.utiliserEmpriseVisible()
      }

      QfButton {
        text: qsTr("Retirer")
        enabled: selecteur.nombreSommets > 0
        bgcolor: "transparent"
        color: Theme.mainTextColor
        borderColor: Theme.controlBorderColor
        onClicked: selecteur.retirerDernierSommet()
      }

      QfButton {
        text: qsTr("Ajouter")
        bgcolor: selecteur.accent
        color: "#ffffff"
        onClicked: selecteur.ajouterSommet()
      }

      QfButton {
        text: qsTr("Terminer")
        enabled: selecteur.empriseValide
        bgcolor: selecteur.empriseValide ? Theme.mainColor : "transparent"
        color: selecteur.empriseValide ? Theme.darkGray : Theme.mainTextDisabledColor
        borderColor: Theme.controlBorderColor
        onClicked: selecteur.terminer()
      }

      QfButton {
        text: qsTr("Annuler")
        bgcolor: "transparent"
        color: Theme.secondaryTextColor
        onClicked: selecteur.abandonner()
      }
    }
  }

  // ===========================================================================
  //  Fonctions
  // ===========================================================================

  // Ouvre le mode tracé. `sommetsInitiaux` permet de reprendre une emprise déjà
  // définie. Renvoie false si la carte n'est pas accessible.
  function demarrer(sommetsInitiaux) {
    if (!carte || !conteneurCarte) {
      iface.logMessage("[IFA] carte inaccessible : tracé d'emprise impossible");
      return false;
    }

    sommets = sommetsInitiaux && sommetsInitiaux.length > 0 ? sommetsInitiaux.slice() : [];
    parent = conteneurCarte;
    visible = true;
    return true;
  }

  // Retire le calque de la carte sans émettre de signal. Appelé aussi par la
  // fenêtre appelante lors de sa destruction, pour ne rien laisser derrière.
  function reinitialiserAffichage() {
    visible = false;
    if (parentInitial) {
      parent = parentInitial;
    }
  }

  // Coordonnée visée par la croix, en CRS de la carte.
  //
  // On passe par `screenToCoordinate` sur le centre géométrique plutôt que par
  // `mapSettings.getCenter(true)` : QField réserve des marges basse et droite
  // pour ses panneaux, et le centre « avec marges » ne coïnciderait alors plus
  // avec la croix affichée.
  function coordonneeVisee() {
    return carte.mapSettings.screenToCoordinate(Qt.point(width / 2, height / 2));
  }

  function ajouterSommet() {
    if (!carte)
      return;

    // Réaffectation obligatoire : muter le tableau en place ne déclenche
    // aucune notification, et le tracé ne serait pas redessiné.
    const liste = sommets.slice();
    liste.push(coordonneeVisee());
    sommets = liste;
  }

  function retirerDernierSommet() {
    if (sommets.length === 0)
      return;

    const liste = sommets.slice();
    liste.pop();
    sommets = liste;
  }

  // Rectangle correspondant à la vue courante. Les quatre coins écran sont
  // convertis individuellement : le résultat reste correct même lorsque la
  // carte est pivotée.
  function utiliserEmpriseVisible() {
    if (!carte)
      return;

    const parametres = carte.mapSettings;
    sommets = [parametres.screenToCoordinate(Qt.point(0, 0)), parametres.screenToCoordinate(Qt.point(width, 0)), parametres.screenToCoordinate(Qt.point(width, height)), parametres.screenToCoordinate(Qt.point(0, height))];
  }

  function terminer() {
    if (!empriseValide)
      return;

    const wgs84 = CoordinateReferenceSystemUtils.wgs84Crs();
    const crsCarte = carte.mapSettings.destinationCrs;

    const morceaux = [];
    let xmin = Infinity;
    let ymin = Infinity;
    let xmax = -Infinity;
    let ymax = -Infinity;

    for (let i = 0; i < sommets.length; ++i) {
      const point = GeometryUtils.reprojectPoint(sommets[i], crsCarte, wgs84);
      const x = point.x;
      const y = point.y;

      xmin = Math.min(xmin, x);
      ymin = Math.min(ymin, y);
      xmax = Math.max(xmax, x);
      ymax = Math.max(ymax, y);

      // 7 décimales ≈ 1 cm : inutile d'en transporter davantage.
      morceaux.push(x.toFixed(7) + " " + y.toFixed(7));
    }

    // Un anneau WKT doit être explicitement refermé sur son premier sommet.
    morceaux.push(morceaux[0]);

    const wkt = "POLYGON((" + morceaux.join(", ") + "))";

    reinitialiserAffichage();
    valide(wkt, [xmin, ymin, xmax, ymax], sommets.length);
  }

  function abandonner() {
    reinitialiserAffichage();
    annule();
  }
}
