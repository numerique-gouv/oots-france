const OOTS_FRANCE = require('../../src/ootsFrance');
const { ErreurAbsenceReponseDestinataire } = require('../../src/erreurs');

const serveurTest = () => {
  let adaptateurDomibus;
  let adaptateurEnvironnement;
  let adaptateurUUID;
  let depotPointsAcces;
  let depotServicesCommuns;
  let ecouteurDomibus;
  let horodateur;

  let serveur;

  const arrete = (suite) => {
    serveur.arreteEcoute(suite);
  };

  const initialise = (suite) => {
    adaptateurDomibus = {
      envoieMessageRequete: () => Promise.resolve(),
      urlRedirectionDepuisReponse: () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL reçue')),
      pieceJustificativeDepuisReponse: () => Promise.resolve(Buffer.from('')),
    };

    adaptateurEnvironnement = {
      avecRequetePieceJustificative: () => true,
    };

    adaptateurUUID = {
      genereUUID: () => '',
    };

    depotPointsAcces = {
      trouvePointAcces: () => Promise.resolve({}),
    };

    depotServicesCommuns = {
      trouveTypeJustificatif: () => Promise.resolve({}),
      trouveTypesJustificatifsPourDemarche: () => Promise.resolve([]),
    };

    ecouteurDomibus = {
      arreteEcoute: () => {},
      ecoute: () => {},
      etat: () => '',
    };

    horodateur = {
      maintenant: () => '',
    };

    serveur = OOTS_FRANCE.creeServeur({
      adaptateurDomibus,
      adaptateurEnvironnement,
      adaptateurUUID,
      depotPointsAcces,
      depotServicesCommuns,
      ecouteurDomibus,
      horodateur,
    });

    serveur.ecoute(0, suite);
  };

  const port = () => serveur.port();

  return {
    adaptateurDomibus: () => adaptateurDomibus,
    adaptateurEnvironnement: () => adaptateurEnvironnement,
    adaptateurUUID: () => adaptateurUUID,
    arrete,
    depotPointsAcces: () => depotPointsAcces,
    depotServicesCommuns: () => depotServicesCommuns,
    ecouteurDomibus: () => ecouteurDomibus,
    horodateur: () => horodateur,
    initialise,
    port,
  };
};

module.exports = serveurTest;
