const axios = require('axios');

const parametresRequeteVerificationJeton = (jetonAcces) => ({
  client_id: process.env.IDENTIFIANT_CLIENT_FCPLUS,
  client_secret: process.env.SECRET_CLIENT_FCPLUS,
  token: jetonAcces,
});

const verifieJetonAcces = (jetonAcces) => (
  axios.post(
    'https://auth.integ01.dev-franceconnect.fr/api/v2/checktoken',
    parametresRequeteVerificationJeton(jetonAcces),
    { headers: { 'content-type': 'application/x-www-form-urlencoded' } },
  )
);

module.exports = { verifieJetonAcces };
