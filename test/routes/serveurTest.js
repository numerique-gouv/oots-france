const OOTS_FRANCE = require('../../src/ootsFrance');

const serveurTest = () => {
  let adaptateurChiffrement;
  let adaptateurDomibus;
  let adaptateurEnvironnement;
  let adaptateurFranceConnectPlus;
  let adaptateurUUID;
  let depotPointsAcces;
  let ecouteurDomibus;
  let horodateur;

  let serveur;

  const arrete = (suite) => {
    serveur.arreteEcoute(suite);
  };

  const initialise = (suite) => {
    adaptateurChiffrement = {
      genereJeton: () => Promise.resolve(),
    };

    adaptateurDomibus = {};

    adaptateurEnvironnement = {
      avecEnvoiCookieSurHTTP: () => 'true',
      secretJetonSession: () => 'secret',
    };

    adaptateurFranceConnectPlus = {};

    adaptateurUUID = {
      genereUUID: () => '',
    };

    depotPointsAcces = {};

    ecouteurDomibus = {
      arreteEcoute: () => {},
      ecoute: () => {},
      etat: () => '',
    };

    horodateur = {
      maintenant: () => '',
    };

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

    serveur.ecoute(0, suite);
  };

  const port = () => serveur.port();

  return {
    adaptateurChiffrement: () => adaptateurChiffrement,
    adaptateurDomibus: () => adaptateurDomibus,
    adaptateurEnvironnement: () => adaptateurEnvironnement,
    adaptateurFranceConnectPlus: () => adaptateurFranceConnectPlus,
    adaptateurUUID: () => adaptateurUUID,
    arrete,
    depotPointsAcces: () => depotPointsAcces,
    ecouteurDomibus: () => ecouteurDomibus,
    horodateur: () => horodateur,
    initialise,
    port,
  };
};

module.exports = serveurTest;
