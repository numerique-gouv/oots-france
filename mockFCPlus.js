const express = require('express');
const jose = require('jose');

const adaptateurChiffrement = require('./src/adaptateurs/adaptateurChiffrement');

const JETON_CAS_SIGNATURE_INVALIDE = 'jetonCasSignatureInvalide';

const jwkValide = {
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

const jwkInvalide = {
  kty: 'RSA',
  n: 'y6CltudeoaMikeSwChFGWePEDUJevbb-pb2o0aDREQ_7jqfwUR6uCGU_eXmEfIor-f3afasfBmbpiKIHSPosUFSbpImkBoCwd5W8miSBwhWIxYIgUnsjGu4nfaM9i2NtHc4EGG8SM5yQd6i6Eb1q2KTbjwIzsPAMTwnrGmYmeFVZPK6wdtDYKuXzrmt6CcBZu3duG4Y0uhz-DhssVgZQZIMyn6mEnep-XsvKvRjNU7Gl26woWnHueIlcG0e4WaoPxbc5Xd1ZbT7Bu6M8N3FjHHS6FrXIqeYtrzJOtwDe37IOsuR4d87n_cNKf311fXK6iYYimoSOQwsSAG6WgalfNw',
  e: 'AQAB',
  d: 'W8BlKwcR0s9JEmfzEnY6NuK0Qi03t1AvacsNuHc3_PIwrVTqqgKi9FF6ymeA1QUFT72cp6dlcWMJs3Eeyzk-omudPgRvDicKXLfxpZrxhNxjJmu92Kx3YvkQfkIBxz7judxMaB4UG4FebyxtuvSYokmWTNf3JrDjOvIDJ4ADsZAlb3QXzJwRzKMzYMN6PAt5CW9CEPqR_nwu9p_zlUFtC4qDXitfmSpLO5quZTpDJrBYWsnHdj77pe3knqcjw8lTGLCojSDmCydbG7hkz3Xq31-eY0YFOPJgWcbQMkLiyF0y5GsF1CjRKFNywgfxljzRzEiLCs4Ihof0phkX-vqT4Q',
  p: '8coKPaGjRE9q-xjVRLfAWpJ9aW6D6xUVGeC26jJu9D2nPyG3mpORzn72EtP_VxsHK7KQ4DnNgvT000-mSeiKkjufxTss7N2-TJUupkc0IJpr5QjDXP3fJcplJGyF6BgBVaUuJJWytRrrBrdQBtCKv5dNkhdDNZFhIB7TYPGs5ak',
  q: '15htNxigCp5aq23f5507wKFamM_sOZSKYldTNod8XJOtnYXT1ZOY7AWUwHWIs3glU8xlw9GX1VJcWn9YGqe6rYgd_yxVglq2PR7vVhUuT7Dym0r5Z1Q605DAqh3tyVfFkegxYB0kNwmSw3LHvxsxCyXeaUOzeRO5oDM4SyXjad8',
  dp: 'Eeh69bGhHBAdxldChIJvlsW-0C5FSwYWuAHyyknN-f0PBBgFN0eyxu6UXzSgdt0jnNLu9AyT8h0efQArOtIkYUxVOxB09V4_GAD8oYgojjmhwCb0AVE0U-I3t4jqKhSNFMDVOBR2Vf-WZLrzDG4puKMGNcnPSopn_S8LTOTZf3E',
  dq: 'vuFNkQJUcBJT5IObQc2MIbi6JaGxXCmPfBIkspqyGKUHiff63ZWYRx-J2_wz0_ID2nWVhBIFg_Evo1AsCS2HsixZopr1-jumLec9r9GA9z2LDsMKndmNW9NFQVjONv1nBw-054vljHUFY9Yz05eXjG8yw7AVLpWwO44dwSsCdbE',
  qi: 'tA3h9_ecg1pu9zenGhdkW9lY7HqU3a41ROPQxYVX8rVybgwiO7MlqBQmy2zgezB5NQfzIgeWMtgThemN5RiQ3bunGRBOHL9PFjMo_aGO3hZkj93EdoxZBiIlLwJX11yxmMBC05jojVR-2XjX9Eijs5xmFdrjkngmwlAhbYyz6M0',
};

const ootsJWK = JSON.parse(atob(process.env.CLE_PRIVEE_JWK_EN_BASE64));

const enJWE = (cleSignature, infos) => {
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

  return jose.importJWK(cleSignature)
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
        .encrypt(clePrivee)));
};

const port = 4000;
const app = express();

app.use(express.urlencoded({ extended: true }));

app.get('/', (_requete, reponse) => {
  reponse.json({
    authorization_endpoint: `${process.env.URL_BASE_MOCK_FCPLUS}/debut_session`,
    end_session_endpoint: `${process.env.URL_BASE_MOCK_FCPLUS}/fin_session`,
    jwks_uri: `${process.env.URL_BASE_MOCK_FCPLUS}/jwks`,
    token_endpoint: `${process.env.URL_BASE_MOCK_FCPLUS}/jeton`,
    userinfo_endpoint: `${process.env.URL_BASE_MOCK_FCPLUS}/userinfo`,
  });
});

app.get('/debut_session', (requete, reponse) => {
  const etat = requete.params.state;
  reponse.redirect(`${process.env.URL_REDIRECTION_CONNEXION}?state=${etat}&code=abcdef`);
});

app.get('/fin_session', (_requete, reponse) => {
  reponse.redirect(process.env.URL_REDIRECTION_DECONNEXION);
});

app.post('/jeton', (requete, reponse) => {
  const { code } = requete.body;
  const jeton = (code === 'XXX') ? JETON_CAS_SIGNATURE_INVALIDE : 'unJeton';

  enJWE(jwkValide, {})
    .then((jwe) => reponse.json({ access_token: jeton, id_token: jwe }));
});

app.get('/jwks', (_requete, reponse) => {
  const { kty, n, e } = jwkValide;

  reponse.json({
    keys: [{
      use: 'sig',
      kty,
      n,
      e,
    }],
  });
});

app.get('/userinfo', (requete, reponse) => {
  const jeton = requete.headers.authorization.match(/Bearer (.*)/)[1];
  const cleSignature = (jeton === JETON_CAS_SIGNATURE_INVALIDE) ? jwkInvalide : jwkValide;

  const envoieInfos = (infos) => enJWE(cleSignature, infos)
    .then((jwe) => reponse.send(jwe));

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
