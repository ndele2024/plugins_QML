// =============================================================================
//  FenetreModifierProjet — consultation et modification d'un projet existant
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

  titre: qsTr("Modifier / Afficher un projet")
  soustitre: qsTr("Projet d'inventaire existant")
  icone: "ic_edit_attributes_white_24dp"
  accent: Theme.mainColor

  onOpened: {
    if (referentiels)
      referentiels.chargerProjets();
  }

  IfaChantier {
    Layout.fillWidth: true

    accent: fenetre.accent
    description: {
      if (referentiels && referentiels.projetsCharges)
        return qsTr("Cette fenêtre permettra de consulter et de corriger un projet existant. %n projet(s) en production sont actuellement lisibles dans le projet ouvert.", "", referentiels.projets.length);
      return qsTr("Cette fenêtre permettra de consulter et de corriger un projet existant.");
    }

    etapes: [qsTr("Sélection du projet dans la liste filtrée par région (déjà disponible via Referentiels.projetsDeLaRegion)."), qsTr("Affichage des champs en lecture seule, puis passage en modification selon les droits de l'utilisateur."), qsTr("Enregistrement dans la couche « proje_sonda » et journalisation de la modification.")]
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
