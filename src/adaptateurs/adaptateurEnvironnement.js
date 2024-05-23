const avecRequetePieceJustificative = () => process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE === 'true';

const identifiantEIDAS = () => process.env.IDENTIFIANT_EIDAS;

module.exports = {
  avecRequetePieceJustificative,
  identifiantEIDAS,
};
