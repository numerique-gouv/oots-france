const avecEnvoiCookieSurHTTP = () => process.env.AVEC_ENVOI_COOKIE_SUR_HTTP === 'true';

const avecRequetePieceJustificative = () => process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE === 'true';

const identifiantEIDAS = () => process.env.IDENTIFIANT_EIDAS;

const secretJetonSession = () => new TextEncoder().encode(process.env.SECRET_JETON_SESSION);

module.exports = {
  avecEnvoiCookieSurHTTP,
  avecRequetePieceJustificative,
  identifiantEIDAS,
  secretJetonSession,
};
