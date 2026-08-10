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

// Obligatoire : sans base, aucun échange n'est journalisé, et l'article 17 du
// règlement (UE) 2022/1463 n'est pas tenu. Mieux vaut refuser de démarrer que
// de requêter sans laisser de trace.
const urlBaseDonnees = () => variableObligatoire('URL_BASE_DONNEES')

module.exports = {
  avecRequetePieceJustificative,
  clePriveeJWK,
  donneesDepotServicesCommunsLocal,
  donneesRequeteurs,
  identiteFournisseurFrancais,
  urlBaseDonnees,
}
