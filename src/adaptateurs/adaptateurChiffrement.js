const crypto = require('crypto');
const jose = require('jose');

const adaptateurEnvironnement = require('./adaptateurEnvironnement');

const cleHachage = (chaine) => crypto.createHash('md5').update(chaine).digest('hex');

const dechiffreJWE = (jwe, urlJWKS) => {
  const jwks = jose.createRemoteJWKSet(new URL(urlJWKS));

  return jose
    .importJWK(adaptateurEnvironnement.clePriveeJWK())
    .then((k) => jose.compactDecrypt(jwe, k))
    .then(({ plaintext }) => plaintext.toString())
    .then((jwt) => jose.jwtVerify(jwt, jwks))
    .then(({ payload }) => payload);
};

module.exports = {
  cleHachage,
  dechiffreJWE,
};
