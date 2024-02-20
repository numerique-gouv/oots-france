const axios = require('axios');

const { leveErreur } = require('./utils');
const { ErreurEchecAuthentification } = require('../../src/erreurs');

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
      serveur.adaptateurEnvironnement().clePriveeJWK = () => ({ e: 'AQAB', n: '503as-2qay5...', kty: 'RSA' });
      serveur.adaptateurChiffrement().cleHachage = (chaine) => `hash de ${chaine}`;

      return axios.get(`http://localhost:${port}/auth/cles_publiques`)
        .then((reponse) => {
          expect(reponse.status).toEqual(200);
          expect(reponse.data).toEqual({
            keys: [{
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

  describe('sur GET /auth/fcplus/connexion', () => {
    describe('lorsque les paramètres `code` et `state` sont présents', () => {
      it('sert les infos utilisateur', () => {
        serveur.adaptateurFranceConnectPlus().recupereInfosUtilisateur = () => (
          Promise.resolve({ infos: 'des infos' })
        );

        return axios.get(`http://localhost:${port}/auth/fcplus/connexion?state=unState&code=unCode`)
          .then((reponse) => {
            expect(reponse.status).toBe(200);
            expect(reponse.data).toEqual({ infos: 'des infos' });
          })
          .catch(leveErreur);
      });

      it("sert une erreur HTTP 502 (Bad Gateway) quand l'authentification échoue", () => {
        expect.assertions(2);

        serveur.adaptateurFranceConnectPlus().recupereInfosUtilisateur = () => (
          Promise.reject(new ErreurEchecAuthentification('Oups'))
        );

        return axios.get(`http://localhost:${port}/auth/fcplus/connexion?code=unCode&state=unState`)
          .catch(({ response }) => {
            expect(response.status).toBe(502);
            expect(response.data).toEqual({ erreur: 'Échec authentification (Oups)' });
          });
      });
    });

    it("sert une erreur HTTP 400 (Bad Request) si le paramètre 'code' est manquant", () => {
      expect.assertions(2);

      return axios.get(`http://localhost:${port}/auth/fcplus/connexion?state=unState`)
        .catch(({ response }) => {
          expect(response.status).toBe(400);
          expect(response.data).toEqual({ erreur: "Paramètre 'code' absent de la requête" });
        });
    });

    it("sert une erreur HTTP 400 (Bad Request) si le paramètre 'state' est manquant", () => {
      expect.assertions(2);

      return axios.get(`http://localhost:${port}/auth/fcplus/connexion?code=unCode`)
        .catch(({ response }) => {
          expect(response.status).toBe(400);
          expect(response.data).toEqual({ erreur: "Paramètre 'state' absent de la requête" });
        });
    });
  });
});
