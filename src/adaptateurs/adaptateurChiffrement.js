const crypto = require('crypto');
const jose = require('jose');

const adaptateurEnvironnement = require('./adaptateurEnvironnement');
const { ErreurJetonInvalide } = require('../erreurs');

const cleHachage = (chaine) => crypto.createHash('md5').update(chaine).digest('hex');

const genereJeton = (donnees) => new jose.SignJWT(donnees)
  .setProtectedHeader({ alg: 'HS256' })
  .sign(adaptateurEnvironnement.secretJetonSession());

const verifieJeton = (jeton, secret) => {
  if (typeof jeton === 'undefined') {
    return Promise.resolve();
  }

  return jose.jwtVerify(jeton, secret)
    .then(({ payload }) => payload)
    .catch((e) => Promise.reject(new ErreurJetonInvalide(e)));
};

module.exports = { cleHachage, genereJeton, verifieJeton };
