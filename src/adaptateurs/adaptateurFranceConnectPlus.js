const axios = require('axios');
const adaptateurEnvironnement = require('./adaptateurEnvironnement');

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

const recupereInfosUtilisateurChiffrees = (jetonAcces) => configurationOpenIdFranceConnectPlus
  .then(({ userinfo_endpoint: urlRecuperationInfosUtilisateur }) => (
    axios.get(
      urlRecuperationInfosUtilisateur,
      { headers: { Authorization: `Bearer ${jetonAcces}` } },
    )
  ))
  .then(({ data }) => data);

const recupereURLClefsPubliques = () => configurationOpenIdFranceConnectPlus
  .then(({ jwks_uri: url }) => url);

module.exports = {
  recupereDonneesJetonAcces,
  recupereInfosUtilisateurChiffrees,
  recupereURLClefsPubliques,
};
