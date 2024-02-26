const axios = require('axios');

const OOTS_FRANCE = require('../src/ootsFrance');

describe('Le serveur OOTS France', () => {
  const adaptateurChiffrement = {};
  const adaptateurDomibus = {};
  const adaptateurEnvironnement = {};
  const adaptateurFranceConnectPlus = {};
  const adaptateurUUID = {};
  const depotPointsAcces = {};
  const ecouteurDomibus = {};
  const horodateur = {};

  let port;
  let serveur;

  beforeEach((suite) => {
    adaptateurChiffrement.cleHachage = () => '';
    adaptateurChiffrement.genereJeton = () => Promise.resolve();
    adaptateurEnvironnement.avecRequetePieceJustificative = () => 'true';
    adaptateurEnvironnement.avecEnvoiCookieSurHTTP = () => 'true';
    adaptateurEnvironnement.secretJetonSession = () => 'secret';
    adaptateurFranceConnectPlus.recupereInfosUtilisateur = () => Promise.resolve({});
    adaptateurUUID.genereUUID = () => '';
    depotPointsAcces.trouvePointAcces = () => Promise.resolve({});
    ecouteurDomibus.arreteEcoute = () => {};
    ecouteurDomibus.etat = () => '';
    horodateur.maintenant = () => '';

    serveur = OOTS_FRANCE.creeServeur({
      adaptateurChiffrement,
      adaptateurDomibus,
      adaptateurEnvironnement,
      adaptateurFranceConnectPlus,
      adaptateurUUID,
      depotPointsAcces,
      ecouteurDomibus,
      horodateur,
    });
    serveur.ecoute(0, () => {
      port = serveur.port();
      suite();
    });
  });

  afterEach((suite) => {
    serveur.arreteEcoute(suite);
  });

  describe('sur GET /', () => {
    beforeEach(() => {
      adaptateurChiffrement.verifieJeton = () => Promise.resolve();
    });

    it("affiche qu'il n'y a pas pas d'utilisateur courant par défaut", () => (
      axios.get(`http://localhost:${port}/`)
        .then((reponse) => {
          expect(reponse.status).toBe(200);
          expect(reponse.data).toContain("Pas d'utilisateur courant");
        })
    ));

    it("affiche prénom et nom de l'utilisateur courant s'il existe", () => {
      adaptateurChiffrement.verifieJeton = () => Promise.resolve({
        given_name: 'Sandra',
        family_name: 'Nicouette',
      });

      return axios.get(`http://localhost:${port}/`)
        .then((reponse) => {
          expect(reponse.status).toBe(200);
          expect(reponse.data).toContain('Utilisateur courant : Sandra Nicouette');
        });
    });
  });
});
