const axios = require('axios');
const adaptateurEnvironnement = require('./adaptateurEnvironnement');
const adaptateurChiffrement = require('./adaptateurChiffrement');
const { ErreurEchecAuthentification } = require('../erreurs');
const SessionFCPlus = require('../modeles/sessionFCPlus');

const configurationOpenIdFranceConnectPlus = axios
  .get(adaptateurEnvironnement.urlConfigurationOpenIdFCPlus())
  .then(({ data }) => data);

const parametresRequeteJeton = (code) => Object.assign(
  adaptateurEnvironnement.parametresRequeteJeton(),
  { code, grant_type: 'authorization_code' },
);

const recupereDonneesJetonAcces = (code) => configurationOpenIdFranceConnectPlus
  .then(({ token_endpoint: urlRecuperationJetonAcces }) => (
    axios.post(
      urlRecuperationJetonAcces,
      parametresRequeteJeton(code),
      { headers: { 'content-type': 'application/x-www-form-urlencoded' } },
    )
  ))
  .then(({ data }) => data);

const initialiseSessionFCPlus = (donnees) => adaptateurChiffrement.dechiffreJWE(donnees.id_token)
  .then((jwt) => new SessionFCPlus({ jetonAcces: donnees.access_token, jwt }));

const creeSessionFCPlus = (code) => recupereDonneesJetonAcces(code)
  .then(initialiseSessionFCPlus);

const recupereInfosUtilisateurChiffrees = (sessionFCPlus) => configurationOpenIdFranceConnectPlus
  .then(({ userinfo_endpoint: urlRecuperationInfosUtilisateur }) => (
    axios.get(
      urlRecuperationInfosUtilisateur,
      { headers: { Authorization: `Bearer ${sessionFCPlus.jetonAcces}` } },
    )
  ))
  .then(({ data }) => sessionFCPlus.avecInfosUtilisateurChiffrees(data));

const verifieSignatureJWT = (jwt) => configurationOpenIdFranceConnectPlus
  .then(({ jwks_uri: url }) => adaptateurChiffrement.verifieSignatureJWTDepuisJWKS(jwt, url));

const dechiffreInfosUtilisateur = (sessionFCPlus) => (
  adaptateurChiffrement.dechiffreJWE(sessionFCPlus.infosUtilisateurChiffrees)
    .then(verifieSignatureJWT)
    .then((infosDechiffrees) => Object.assign(infosDechiffrees, {
      jwtSessionFCPlus: sessionFCPlus.jwt,
    }))
);

const recupereInfosUtilisateur = (code) => creeSessionFCPlus(code)
  .then(recupereInfosUtilisateurChiffrees)
  .then(dechiffreInfosUtilisateur)
  .catch((e) => Promise.reject(new ErreurEchecAuthentification(e.message)));

module.exports = { recupereInfosUtilisateur };
