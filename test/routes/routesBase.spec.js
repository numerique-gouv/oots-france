const axios = require('axios');

const serveurTest = require('./serveurTest');
const { leveErreur } = require('./utils');

describe('Le serveur des routes `/`', () => {
  const serveur = serveurTest();
  let port;

  beforeEach((suite) => serveur.initialise(() => {
    port = serveur.port();
    suite();
  }));

  afterEach((suite) => serveur.arrete(suite));

  describe('sur GET /', () => {
    it("affiche qu'il n'y a pas pas d'utilisateur courant par défaut", () => (
      axios.get(`http://localhost:${port}/`)
        .then((reponse) => {
          expect(reponse.status).toBe(200);
          expect(reponse.data).toContain("Pas d'utilisateur courant");
        })
        .catch(leveErreur)));
  });
});
