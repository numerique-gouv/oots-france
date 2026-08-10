const crypto = require('crypto')
const jose = require('jose')

const adaptateurEnvironnement = require('./adaptateurEnvironnement')
const { ErreurJetonInvalide } = require('../erreurs')

const cleHachage = chaine => crypto.createHash('md5').update(chaine).digest('hex')

// L'empreinte du justificatif consignée au journal. Elle prouve après coup
// qu'un document donné est celui qui a transité, sans que le journal ait à
// conserver la pièce — que l'article 17 du règlement (UE) 2022/1463 exclut
// justement. MD5 ci-dessus reste cantonné à son usage de clé.
const empreinteSha256 = contenu => crypto.createHash('sha256').update(contenu).digest('hex')

const dechiffreJWE = (jwe, urlJWKS) => {
  const jwks = jose.createRemoteJWKSet(new URL(urlJWKS))

  return jose
    .importJWK(adaptateurEnvironnement.clePriveeJWK())
    .then(k => jose.compactDecrypt(jwe, k))
    // jose 6 rend un `Uint8Array` nu, là où la 5 rendait un `Buffer` de Node :
    // `toString()` y donnerait la liste des octets (« 98,111,110,… ») au lieu
    // du jeton, et la vérification échouerait sans rien dire d'utile.
    .then(({ plaintext }) => new TextDecoder().decode(plaintext))
    .then(jwt => jose.jwtVerify(jwt, jwks))
    .then(({ payload }) => payload)
    .catch(e => Promise.reject(new ErreurJetonInvalide(e)))
}

module.exports = {
  cleHachage,
  dechiffreJWE,
  empreinteSha256,
}
