const crypto = require('crypto');
const jose = require('jose');

const adaptateurEnvironnement = require('./adaptateurEnvironnement');

const cleHachage = (chaine) => crypto.createHash('md5').update(chaine).digest('hex');

const genereJeton = (donnees) => new jose.SignJWT(donnees)
  .setProtectedHeader({ alg: 'HS256' })
  .sign(adaptateurEnvironnement.secretJetonSession());

const verifieJeton = (jeton) => {
  if (typeof jeton === 'undefined') {
    return Promise.resolve();
  }

  const secret = adaptateurEnvironnement.secretJetonSession();
  return jose.jwtVerify(jeton, secret)
    .then(({ payload }) => payload);
};

module.exports = { cleHachage, genereJeton, verifieJeton };
