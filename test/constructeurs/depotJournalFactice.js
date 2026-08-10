// Un dépôt du journal qui retient ce qu'on lui confie au lieu de l'écrire.
//
// Les points d'émission sont dispersés — l'API, l'adaptateur Domibus, le
// serveur de test —, et tous ont besoin de la même chose : vérifier qu'un
// événement a été consigné, avec les bonnes valeurs, sans base de données.
const depotJournalFactice = () => {
  const evenements = []

  const consigne = typeEvenement => (donnees = {}) => {
    evenements.push({ typeEvenement, ...donnees })
    return Promise.resolve()
  }

  return {
    evenements,
    evenementsDeType: type => evenements.filter(e => e.typeEvenement === type),
    consigneRequeteEmise: consigne('requete_emise'),
    consigneReponseRecue: consigne('reponse_recue'),
    consigneErreurRecue: consigne('erreur_recue'),
    consigneRequeteRecue: consigne('requete_recue'),
    consigneReponseEmise: consigne('reponse_emise'),
    consignePieceTransmise: consigne('piece_transmise'),
    consigneRequeteRefusee: consigne('requete_refusee'),
  }
}

module.exports = depotJournalFactice
