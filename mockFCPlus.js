const express = require('express');
const jose = require('jose');

const adaptateurChiffrement = require('./src/adaptateurs/adaptateurChiffrement');

const app = express();
const port = 4000;

const jwk = {
  kty: 'RSA',
  n: 'whYOFK2Ocbbpb_zVypi9SeKiNUqKQH0zTKN1-6fpCTu6ZalGI82s7XK3tan4dJt90ptUPKD2zvxqTzFNfx4HHHsrYCf2-FMLn1VTJfQazA2BvJqAwcpW1bqRUEty8tS_Yv4hRvWfQPcc2Gc3-_fQOOW57zVy-rNoJc744kb30NjQxdGp03J2S3GLQu7oKtSDDPooQHD38PEMNnITf0pj-KgDPjymkMGoJlO3aKppsjfbt_AH6GGdRghYRLOUwQU-h-ofWHR3lbYiKtXPn5dN24kiHy61e3VAQ9_YAZlwXC_99GGtw_NpghFAuM4P1JDn0DppJldy3PGFC0GfBCZASw',
  e: 'AQAB',
  d: 'VuVE_KEP6323WjpbBdAIv7HGahGrgGANvbxZsIhm34lsVOPK0XDegZkhAybMZHjRhp-gwVxX5ChC-J3cUpOBH5FNxElgW6HizD2Jcq6t6LoLYgPSrfEHm71iHg8JsgrqfUnGYFzMJmv88C6WdCtpgG_qJV1K00_Ly1G1QKoBffEs-v4fAMJrCbUdCz1qWto-PU-HLMEo-krfEpGgcmtZeRlDADh8cETMQlgQfQX2VWq_aAP4a1SXmo-j0cvRU4W5Fj0RVwNesIpetX2ZFz4p_JmB5sWFEj_fC7h5z2lq-6Bme2T3BHtXkIxoBW0_pYVnASC8P2puO5FnVxDmWuHDYQ',
  p: '07rgXd_tLUhVRF_g1OaqRZh5uZ8hiLWUSU0vu9coOaQcatSqjQlIwLW8UdKv_38GrmpIfgcEVQjzq6rFBowUm9zWBO9Eq6enpasYJBOeD8EMeDK-nsST57HjPVOCvoVC5ZX-cozPXna3iRNZ1TVYBY3smn0IaxysIK-zxESf4pM',
  q: '6qrE9TPhCS5iNR7QrKThunLu6t4H_8CkYRPLbvOIt2MgZyPLiZCsvdkTVSOX76QQEXt7Y0nTNua69q3K3Jhf-YOkPSJsWTxgrfOnjoDvRKzbW3OExIMm7D99fVBODuNWinjYgUwGSqGAsb_3TKhtI-Gr5ls3fn6B6oEjVL0dpmk',
  dp: 'mHqjrFdgelT2OyiFRS3dAAPf3cLxJoAGC4gP0UoQyPocEP-Y17sQ7t-ygIanguubBy65iDFLeGXa_g0cmSt2iAzRAHrDzI8P1-pQl2KdWSEg9ssspjBRh_F_AiJLLSPRWn_b3-jySkhawtfxwO8Kte1QsK1My765Y0zFvJnjPws',
  dq: 'KmjaV4YcsVAUp4z-IXVa5htHWmLuByaFjpXJOjABEUN0467wZdgjn9vPRp-8Ia8AyGgMkJES_uUL_PDDrMJM9gb4c6P4-NeUkVtreLGMjFjA-_IQmIMrUZ7XywHsWXx0c2oLlrJqoKo3W-hZhR0bPFTYgDUT_mRWjk7wV6wl46E',
  qi: 'iYltkV_4PmQDfZfGFpzn2UtYEKyhy-9t3Vy8Mw2VHLAADKGwJvVK5ficQAr2atIF1-agXY2bd6KV-w52zR8rmZfTr0gobzYIyqHczOm13t7uXJv2WygY7QEC2OGjdxa2Fr9RnvS99ozMa5nomZBqTqT7z5QV33czjPRCjvg6FcE',
};

const ootsJWK = JSON.parse(atob(process.env.CLE_PRIVEE_JWK_EN_BASE64));

app.get('/', (_requete, reponse) => {
  reponse.json({
    token_endpoint: `${process.env.URL_BASE_MOCK_FCPLUS}/jeton`,
    userinfo_endpoint: `${process.env.URL_BASE_MOCK_FCPLUS}/userinfo`,
  });
});

app.post('/jeton', (_requete, reponse) => {
  reponse.json({ access_token: 'unJeton' });
});

app.get('/userinfo', (_requete, reponse) => {
  const envoieInfos = (infos) => {
    const headerJWT = {
      alg: 'RS256',
    };

    const headerJWE = {
      alg: 'RSA-OAEP',
      enc: 'A256GCM',
      cty: 'JWT',
      kid: adaptateurChiffrement.cleHachage(ootsJWK.n),
      iss: 'http://oots',
      aud: process.env.IDENTIFIANT_CLIENT_FCPLUS,
    };

    jose.importJWK(jwk)
      .then((clePrivee) => new jose.SignJWT(infos)
        .setProtectedHeader(headerJWT)
        .setIssuedAt()
        .setIssuer('http://mock_fcplus')
        .setAudience(process.env.IDENTIFIANT_CLIENT_FCPLUS)
        .setExpirationTime('1h')
        .sign(clePrivee))
      .then((jwt) => jose.importJWK(ootsJWK)
        .then((clePrivee) => new jose.CompactEncrypt(new TextEncoder().encode(jwt))
          .setProtectedHeader(headerJWE)
          .encrypt(clePrivee)))
      .then((jwe) => reponse.send(jwe));
  };

  envoieInfos({
    given_name: 'Anne-Juliette',
    family_name: 'HAUDEBERT',
    birthdate: '1962-08-24',
    gender: 'female',
    sub: '1234567890abcdef',
  });
});

app.listen(port, () => {
  /* eslint-disable no-console */

  console.log(`Mock FCPlus est démarré et écoute sur le port ${port} !…`);

  /* eslint-enable no-console */
});
