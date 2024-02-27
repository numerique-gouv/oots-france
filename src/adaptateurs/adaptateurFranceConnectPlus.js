const axios = require('axios');
const jose = require('jose');

const adaptateurEnvironnement = require('./adaptateurEnvironnement');
const adaptateurChiffrement = require('./adaptateurChiffrement');
const { ErreurEchecAuthentification } = require('../erreurs');

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
  .then(({ data: { access_token: jetonAcces } }) => jetonAcces);

const recupereInfosUtilisateurChiffrees = (jeton) => configurationOpenIdFranceConnectPlus
  .then(({ userinfo_endpoint: urlRecuperationInfosUtilisateur }) => (
    axios.get(
      urlRecuperationInfosUtilisateur,
      { headers: { Authorization: `Bearer ${jeton}` } },
    )
  ))
  .then(({ data }) => data);

const verifieSignatureJWT = (jwt) => configurationOpenIdFranceConnectPlus
  .then(({ jwks_uri: urlJWKS }) => jose.createRemoteJWKSet(new URL(urlJWKS)))
  .then((jwks) => adaptateurChiffrement.verifieJeton(jwt, jwks));

const dechiffreInfosUtilisateur = (infos) => jose
  .importJWK(adaptateurEnvironnement.clePriveeJWK())
  .then((clePrivee) => jose.compactDecrypt(infos, clePrivee))
  .then(({ plaintext }) => verifieSignatureJWT(plaintext));

const recupereInfosUtilisateur = (code) => recupereJetonAcces(code)
  .then(recupereInfosUtilisateurChiffrees)
  .then(dechiffreInfosUtilisateur)
  .catch((e) => Promise.reject(new ErreurEchecAuthentification(e.message)));

module.exports = { recupereInfosUtilisateur };
