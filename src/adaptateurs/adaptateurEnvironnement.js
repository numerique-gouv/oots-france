const { ErreurConfiguration } = require('../erreurs')

// Une variable absente ou vide se propagerait en `undefined` dans les messages
// sortants, que Domibus accepterait — la propriété est présente, seule sa
// valeur est absurde. Mieux vaut refuser de démarrer.
const variableObligatoire = (nom) => {
  const valeur = process.env[nom]

  if (typeof valeur === 'undefined' || valeur.trim() === '') {
    throw new ErreurConfiguration(`La variable d'environnement ${nom} est obligatoire et ne peut pas être vide.`)
  }

  return valeur
}

const avecRequetePieceJustificative = () => process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE === 'true'

const clePriveeJWK = () => JSON.parse(atob(process.env.CLE_PRIVEE_JWK_EN_BASE64))

const donneesDepotServicesCommunsLocal = () => (
  JSON.parse(process.env.DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL)
)

const donneesRequeteurs = () => JSON.parse(process.env.DONNEES_REQUETEURS)

// L'organisation française qui fournit les justificatifs : son identité est
// estampillée sur chaque réponse et chaque erreur émises.
const identiteFournisseurFrancais = () => ({
  id: variableObligatoire('IDENTIFIANT_FOURNISSEUR_FRANCAIS'),
  nom: variableObligatoire('NOM_FOURNISSEUR_FRANCAIS'),
})

// L'adresse à laquelle l'espace de prévisualisation d'un autre État membre
// ramène l'usager une fois qu'il a choisi. Obligatoire pour la même raison que
// l'identité ci-dessus : absente, elle partirait en `returnurl=undefined` chez
// le correspondant, qui l'accepterait sans rien dire.
const urlOotsFrance = () => variableObligatoire('URL_OOTS_FRANCE')

module.exports = {
  avecRequetePieceJustificative,
  clePriveeJWK,
  donneesDepotServicesCommunsLocal,
  donneesRequeteurs,
  identiteFournisseurFrancais,
  urlOotsFrance,
}
