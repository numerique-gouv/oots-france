const axios = require('axios');

const { leveErreur } = require('./utils');
const serveurTest = require('./serveurTest');

describe('Le serveur des routes `/auth`', () => {
  const serveur = serveurTest();
  let port;

  beforeEach((suite) => serveur.initialise(() => {
    port = serveur.port();
    suite();
  }));

  afterEach((suite) => serveur.arrete(suite));

  describe('sur GET /auth/cles_publiques', () => {
    it('retourne les clés de chiffrement au format JSON Web Key Set', () => {
      serveur.adaptateurEnvironnement().clePriveeJWK = () => ({
        e: 'AQAB',
        n: '503as-2qay5...',
        kty: 'RSA',
      });
      serveur.adaptateurChiffrement().cleHachage = (chaine) => `hash de ${chaine}`;

      return axios.get(`http://localhost:${port}/auth/cles_publiques`)
        .then((reponse) => {
          expect(reponse.status).toEqual(200);
          expect(reponse.data).toEqual({
            keys: [
              {
                kid: 'hash de 503as-2qay5...',
                kty: 'RSA',
                use: 'enc',
                e: 'AQAB',
                n: '503as-2qay5...',
              }],
          });
        })
        .catch(leveErreur);
    });
  });
});
