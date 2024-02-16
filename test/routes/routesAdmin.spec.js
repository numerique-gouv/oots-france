const axios = require('axios');

const serveurTest = require('./serveurTest');
const { leveErreur } = require('./utils');

describe('Le serveur des routes `/admin`', () => {
  const serveur = serveurTest();
  let port;

  beforeEach((suite) => serveur.initialise(() => {
    port = serveur.port();
    suite();
  }));

  afterEach((suite) => serveur.arrete(suite));

  describe('sur POST /admin/arretEcouteDomibus', () => {
    it("arrête d'écouter Domibus", () => {
      let arretEcoute = false;
      serveur.ecouteurDomibus().arreteEcoute = () => {
        arretEcoute = true;
      };

      return axios.post(`http://localhost:${port}/admin/arretEcouteDomibus`)
        .then(() => expect(arretEcoute).toBe(true))
        .catch(leveErreur);
    });

    it("retourne le nouvel état de l'écouteur", () => {
      serveur.ecouteurDomibus().etat = () => 'nouvel état';

      return axios.post(`http://localhost:${port}/admin/arretEcouteDomibus`)
        .then((reponse) => expect(reponse.data).toEqual({ etatEcouteur: 'nouvel état' }))
        .catch(leveErreur);
    });
  });

  describe('sur POST /admin/demarrageEcouteDomibus', () => {
    it('écoute Domibus', () => {
      let demarreEcoute = false;
      serveur.ecouteurDomibus().ecoute = () => {
        demarreEcoute = true;
      };

      return axios.post(`http://localhost:${port}/admin/demarrageEcouteDomibus`)
        .then(() => expect(demarreEcoute).toBe(true))
        .catch(leveErreur);
    });

    it("retourne le nouvel état de l'écouteur", () => {
      serveur.ecouteurDomibus().etat = () => 'nouvel état';

      return axios.post(`http://localhost:${port}/admin/demarrageEcouteDomibus`)
        .then((reponse) => expect(reponse.data).toEqual({ etatEcouteur: 'nouvel état' }))
        .catch(leveErreur);
    });
  });
});
