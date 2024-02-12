const crypto = require('crypto');
const jose = require('jose');

const adaptateurEnvironnement = require('./adaptateurEnvironnement');

const cleHachage = (chaine) => crypto.createHash('md5').update(chaine).digest('hex');

const genereJeton = (donnees) => new jose.SignJWT(donnees)
  .setProtectedHeader({ alg: 'HS256' })
  .sign(adaptateurEnvironnement.secretJetonSession());

const verifieJeton = (jeton) => {
  const secret = adaptateurEnvironnement.secretJetonSession();
  return jose.jwtVerify(jeton, secret);
};

module.exports = { cleHachage, genereJeton, verifieJeton };
