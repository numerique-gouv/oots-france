const avecRequetePieceJustificative = () => process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE === 'true';

const avecEnvoiCookieSurHTTP = () => process.env.AVEC_ENVOI_COOKIE_SUR_HTTP === 'true';

const clePriveeJWK = () => JSON.parse(atob(process.env.CLE_PRIVEE_JWK_EN_BASE64));

const identifiantEIDAS = () => process.env.IDENTIFIANT_EIDAS;

const parametresRequeteJeton = () => ({
  client_id: process.env.IDENTIFIANT_CLIENT_FCPLUS,
  client_secret: process.env.SECRET_CLIENT_FCPLUS,
  redirect_uri: process.env.URL_REDIRECTION_CONNEXION,
});

const secretJetonSession = () => new TextEncoder().encode(process.env.SECRET_JETON_SESSION);

const urlConfigurationOpenIdFCPlus = () => process.env.URL_CONFIGURATION_OPEN_ID_FCPLUS;

module.exports = {
  avecEnvoiCookieSurHTTP,
  avecRequetePieceJustificative,
  clePriveeJWK,
  identifiantEIDAS,
  parametresRequeteJeton,
  secretJetonSession,
  urlConfigurationOpenIdFCPlus,
};
