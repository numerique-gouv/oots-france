const avecRequetePieceJustificative = () => process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE === 'true';

const clePriveeJWK = () => JSON.parse(atob(process.env.CLE_PRIVEE_JWK_EN_BASE64));

module.exports = { avecRequetePieceJustificative, clePriveeJWK };
