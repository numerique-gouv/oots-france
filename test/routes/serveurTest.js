const { ErreurAbsenceReponseDestinataire } = require('../../src/erreurs');
const OOTS_FRANCE = require('../../src/ootsFrance');
const Fournisseur = require('../../src/ebms/fournisseur');
const Requeteur = require('../../src/ebms/requeteur');
const TypeJustificatif = require('../../src/ebms/typeJustificatif');

const serveurTest = () => {
  let adaptateurDomibus;
  let adaptateurEnvironnement;
  let adaptateurUUID;
  let depotPointsAcces;
  let depotRequeteurs;
  let depotServicesCommuns;
  let ecouteurDomibus;
  let horodateur;
  let transmetteurPiecesJustificatives;

  let serveur;

  const arrete = (suite) => {
    serveur.arreteEcoute(suite);
  };

  const initialise = (suite) => {
    adaptateurDomibus = {
      envoieMessageRequete: () => Promise.resolve(),
      urlRedirectionDepuisReponse: () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL reçue')),
      reponseAvecPieceJustificative: () => Promise.resolve({
        idRequeteur: () => '',
        pieceJustificative: () => Buffer.from(''),
      }),
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

    depotRequeteurs = {
      trouveRequeteur: () => Promise.resolve(new Requeteur()),
    };

    depotServicesCommuns = {
      trouveFournisseurs: () => Promise.resolve([new Fournisseur()]),
      trouveTypeJustificatif: () => Promise.resolve({}),
      trouveTypesJustificatifsPourDemarche: () => Promise.resolve([new TypeJustificatif()]),
    };

    ecouteurDomibus = {
      arreteEcoute: () => {},
      ecoute: () => {},
      etat: () => '',
    };

    horodateur = {
      maintenant: () => '',
    };

    transmetteurPiecesJustificatives = {
      envoie: () => Promise.resolve(),
    };

    serveur = OOTS_FRANCE.creeServeur({
      adaptateurDomibus,
      adaptateurEnvironnement,
      adaptateurUUID,
      depotPointsAcces,
      depotRequeteurs,
      depotServicesCommuns,
      ecouteurDomibus,
      horodateur,
      transmetteurPiecesJustificatives,
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
    depotRequeteurs: () => depotRequeteurs,
    depotServicesCommuns: () => depotServicesCommuns,
    ecouteurDomibus: () => ecouteurDomibus,
    horodateur: () => horodateur,
    transmetteurPiecesJustificatives: () => transmetteurPiecesJustificatives,
    initialise,
    port,
  };
};

module.exports = serveurTest;
