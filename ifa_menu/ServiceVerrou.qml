// =============================================================================
//  ServiceVerrou — rendre une unité d'échantillonnage aux autres équipes
// =============================================================================
//  Interroge le point d'accès QFieldCloud
//
//      POST /api/v1/ifa/unites/<une_code_ident>/deverrouiller/
//
//  servi par l'application Django `qfieldcloud.ifa`. C'est la contrepartie du
//  verrou que pose l'ouverture en mode modifiable : le technicien qui a
//  synchronisé ses modifications relâche l'unité, et une autre équipe peut la
//  reprendre.
//
//  ---------------------------------------------------------------------------
//  CE QUE LE SERVEUR ACCEPTE
//  ---------------------------------------------------------------------------
//  La demande n'a pas de corps : le code de l'unité est dans l'URL et le
//  détenteur est celui qui appelle. Le serveur ne laisse **que le détenteur**
//  lever son propre verrou — un technicien ne déverrouille pas l'unité d'un
//  collègue depuis le terrain, celui-ci la croirait encore à lui. C'est aussi
//  pourquoi le bouton n'apparaît que sur les unités que l'utilisateur tient
//  lui-même (voir `TableauUE.utilisateur`) : l'interface ne propose pas un
//  geste que le serveur refusera.
//
//  Une unité qui n'était pas verrouillée n'est pas une erreur — le résultat
//  voulu est déjà là. Le serveur répond alors `deverrouille: false`, et c'est
//  ce que porte le second argument du signal `deverrouille`.
//
//  ---------------------------------------------------------------------------
//  CONTRAT
//  ---------------------------------------------------------------------------
//  Entrée — `deverrouiller(unite)`, une ligne du tableau des résultats **ou**
//  un code d'unité seul. Les deux appelants n'ont pas la même chose en main :
//  `FenetreConsulterUE` tient la ligne entière, `DialogueDeverrouillage` ne
//  connaît que la variable de projet `une_code_ident`.
//
//  Sortie — signal `deverrouille(verrou, change)` où `verrou` est l'état de
//  verrou tel que la base le porte après l'appel :
//      {
//        une_code_ident:      "02-12777-IPE",
//        une_ind_verro:       "N",
//        une_nom_propr_verro: "",
//        une_date_verro:      "",
//        une_raiso_verro:     ""
//      }
//  Il se donne tel quel à `FenetreConsulterUE.appliquerVerrou()`, qui remet la
//  ligne à jour sans relancer la recherche.
//
//  En cas d'échec : signal `echec(message)`, message déjà rédigé — celui du
//  serveur nomme le détenteur quand le refus vient de là.
// =============================================================================

import QtQuick

import org.qfield

QtObject {
  id: service

  // ---------------------------------------------------------------------------
  //  Dépendances injectées
  // ---------------------------------------------------------------------------
  property var session: null

  // ---------------------------------------------------------------------------
  //  État
  // ---------------------------------------------------------------------------
  property bool enCours: false

  // Unité dont le déverrouillage est en cours, ou "" si aucun. Le tableau s'en
  // sert pour montrer l'attente sur la bonne ligne.
  property string uniteCourante: ""

  signal deverrouille(var verrou, bool change)
  signal echec(string message)

  // ---------------------------------------------------------------------------
  //  Interne
  // ---------------------------------------------------------------------------
  // Une demande chasse la précédente : une réponse tardive ne doit pas écrire
  // dans la ligne d'une autre unité.
  property int demandeCourante: 0

  // ===========================================================================
  //  API publique
  // ===========================================================================
  function deverrouiller(unite) {
    if (!session) {
      echec(qsTr("Le service de déverrouillage n'est pas relié à la session QFieldCloud."));
      return;
    }

    const code = codeDe(unite);

    if (code === "") {
      echec(qsTr("Unité d'échantillonnage inconnue."));
      return;
    }

    const numero = ++demandeCourante;

    uniteCourante = code;
    enCours = true;

    // La demande n'a rien à porter, mais on envoie `{}` plutôt que `null` :
    // `SessionCloud` traduit `null` par un corps littéralement vide, que le
    // serveur annonce pourtant en `application/json`.
    session.appeler("POST", "/api/v1/ifa/unites/" + encodeURIComponent(code) + "/deverrouiller/", {}, function (donnees) {
      if (numero !== service.demandeCourante)
        return;
      service.traiterReponse(donnees);
    }, function (message) {
      if (numero !== service.demandeCourante)
        return;
      service.terminer();
      service.echec(message);
    });
  }

  function annuler() {
    demandeCourante++;
    enCours = false;
    uniteCourante = "";
  }

  // ===========================================================================
  //  Interne
  // ===========================================================================
  // Une ligne de résultat, ou le code tout seul.
  function codeDe(unite) {
    if (!unite)
      return "";

    if (typeof unite === "string")
      return unite;

    return unite["une_code_ident"] ? "" + unite["une_code_ident"] : "";
  }

  function traiterReponse(donnees) {
    terminer();

    if (!donnees || donnees.unite === undefined) {
      echec(qsTr("Réponse du serveur illisible."));
      return;
    }

    deverrouille(donnees.unite, donnees.deverrouille === true);
  }

  function terminer() {
    enCours = false;
    uniteCourante = "";
  }
}
