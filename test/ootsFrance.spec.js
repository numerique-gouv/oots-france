const axios = require('axios');
const expect = require('expect.js');

const OOTS_FRANCE = require('../src/ootsFrance');

describe('Le serveur OOTS France', () => {
  const serveur = OOTS_FRANCE.creeServeur();

  beforeEach((suite) => serveur.ecoute(1234, suite));

  afterEach(serveur.arreteEcoute);

  it('sert une erreur HTTP 504 (not implemented)', (suite) => {
    axios.get('http://localhost:1234/')
      .then(() => suite('Réponse OK inattendue'))
      .catch((erreur) => {
        expect(erreur.response.status).to.equal(504);
        suite();
      })
      .catch(suite)
  });
});
