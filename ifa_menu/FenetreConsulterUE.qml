// =============================================================================
//  FenetreConsulterUE — recherche et consultation d'une UE existante
// =============================================================================
//  Squelette : reprendre ce fichier comme modèle pour implémenter la fenêtre.
//  Tout le nécessaire est déjà en place :
//    * `referentiels` donne accès aux couches et aux listes de référence ;
//    * `avertir(message, type)` affiche une notification QField ;
//    * `actions` définit les boutons du pied de page ;
//    * la mise en page responsive est héritée de IfaPopup.
// =============================================================================

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import org.qfield
import Theme

IfaPopup {
  id: fenetre

  titre: qsTr("Consulter une UE")
  soustitre: qsTr("Rechercher une unité d'échantillonnage")
  icone: "ic_baseline_search_white"
  accent: Theme.cloudColor

  IfaChantier {
    Layout.fillWidth: true

    accent: fenetre.accent
    description: qsTr("Cette fenêtre permettra de rechercher une unité d'échantillonnage par son identifiant, son n° de plan d'eau ou sa région, puis d'ouvrir sa fiche en consultation.")

    etapes: [qsTr("Champ de recherche sur la couche « uniteechan » (identifiant, n° LCE, région)."), qsTr("Liste de résultats paginée — la couche compte environ 142 000 unités, le filtrage doit rester côté couche."), qsTr("Ouverture de la fiche en lecture seule, avec zoom sur l'unité dans la carte.")]
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
