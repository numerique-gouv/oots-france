const axios = require('axios');
const jose = require('jose');

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

const recupereJetonAcces = (code) => configurationOpenIdFranceConnectPlus
  .then(({ token_endpoint: urlRecuperationJetonAcces }) => (
    axios.post(
      urlRecuperationJetonAcces,
      parametresRequeteJeton(code),
      { headers: { 'content-type': 'application/x-www-form-urlencoded' } },
    )
  ))
  .then(({ data }) => jose.importJWK(adaptateurEnvironnement.clePriveeJWK())
    .then((k) => jose.compactDecrypt(data.id_token, k))
    .then(({ plaintext }) => new SessionFCPlus({
      jetonAcces: data.access_token,
      jwt: plaintext.toString(),
    })));

const recupereInfosUtilisateurChiffrees = (sessionFCPlus) => configurationOpenIdFranceConnectPlus
  .then(({ userinfo_endpoint: urlRecuperationInfosUtilisateur }) => (
    axios.get(
      urlRecuperationInfosUtilisateur,
      { headers: { Authorization: `Bearer ${sessionFCPlus.jetonAcces}` } },
    )
  ))
  .then(({ data }) => sessionFCPlus.avecInfosUtilisateurChiffrees(data));

const verifieSignatureJWT = (jwt) => configurationOpenIdFranceConnectPlus
  .then(({ jwks_uri: urlJWKS }) => jose.createRemoteJWKSet(new URL(urlJWKS)))
  .then((jwks) => adaptateurChiffrement.verifieJeton(jwt, jwks));

const dechiffreInfosUtilisateur = (sessionFCPlus) => jose
  .importJWK(adaptateurEnvironnement.clePriveeJWK())
  .then((clePrivee) => jose.compactDecrypt(sessionFCPlus.infosUtilisateurChiffrees, clePrivee))
  .then(({ plaintext }) => verifieSignatureJWT(plaintext))
  .then((infosDechiffrees) => Object.assign(infosDechiffrees, {
    jwtSessionFCPlus: sessionFCPlus.jwt,
  }));

const recupereInfosUtilisateur = (code) => recupereJetonAcces(code)
  .then(recupereInfosUtilisateurChiffrees)
  .then(dechiffreInfosUtilisateur)
  .catch((e) => Promise.reject(new ErreurEchecAuthentification(e.message)));

module.exports = { recupereInfosUtilisateur };
