// =============================================================================
//  FenetreCreerProjet — création d'un projet d'inventaire
// =============================================================================
//  Squelette : voir FenetreCreerUE.qml pour un exemple complet de formulaire.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import Theme

IfaPopup {
  id: fenetre

  titre: qsTr("Créer un projet")
  soustitre: qsTr("Nouveau projet d'inventaire")
  icone: "ic_add_white_24dp"
  accent: Theme.mainColor

  IfaChantier {
    Layout.fillWidth: true

    accent: fenetre.accent
    description: qsTr("Cette fenêtre permettra de déclarer un nouveau projet d'inventaire et de lui associer ses types d'unités d'échantillonnage, sur le modèle du formulaire QGIS « projet_ifa ».")

    etapes: [qsTr("Champs du projet : nom, année, région, responsable, statut."), qsTr("Association des types d'UE avec, pour chacun, le nombre d'implantations et de mesurages prévus."), qsTr("Écriture dans la couche « proje_sonda » et dans la table de liaison des types d'UE.")]
  }

  actions: [
    QfButton {
      text: qsTr("Fermer")
      bgcolor: "transparent"
      color: Theme.secondaryTextColor
      onClicked: fenetre.close()
    }
  ]
}
