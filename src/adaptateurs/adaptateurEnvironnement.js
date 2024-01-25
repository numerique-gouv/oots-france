const avecRequetePieceJustificative = () => process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE === 'true';

const clesChiffrement = () => atob(process.env.JSON_WEB_KEY_SET);

module.exports = { avecRequetePieceJustificative, clesChiffrement };
