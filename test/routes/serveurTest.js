const OOTS_FRANCE = require('../../src/ootsFrance');

const MiddlewareFantaisie = require('../mocks/middleware');
const { ErreurAbsenceReponseDestinataire } = require('../../src/erreurs');

const serveurTest = () => {
  let adaptateurChiffrement;
  let adaptateurDomibus;
  let adaptateurEnvironnement;
  let adaptateurFranceConnectPlus;
  let adaptateurUUID;
  let depotPointsAcces;
  let ecouteurDomibus;
  let horodateur;
  let middleware;

  let serveur;

  const arrete = (suite) => {
    serveur.arreteEcoute(suite);
  };

  const initialise = (suite) => {
    adaptateurChiffrement = {
      dechiffreJWE: () => Promise.resolve(),
      genereJeton: () => Promise.resolve(),
      verifieJeton: () => Promise.resolve(),
      verifieSignatureJWTDepuisJWKS: () => Promise.resolve({}),
    };

    adaptateurDomibus = {
      envoieMessageRequete: () => Promise.resolve(),
      urlRedirectionDepuisReponse: () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL reçue')),
      pieceJustificativeDepuisReponse: () => Promise.resolve(Buffer.from('')),
    };

    adaptateurEnvironnement = {
      avecEnvoiCookieSurHTTP: () => true,
      avecRequetePieceJustificative: () => true,
      identifiantEIDAS: () => 'FR/BE/123456789',
      secretJetonSession: () => 'secret',
    };

    adaptateurFranceConnectPlus = {
      recupereDonneesJetonAcces: () => Promise.resolve({}),
      recupereInfosUtilisateurChiffrees: () => Promise.resolve(),
      recupereURLClefsPubliques: () => Promise.resolve(),
    };

    adaptateurUUID = {
      genereUUID: () => '',
    };

    depotPointsAcces = {
      trouvePointAcces: () => Promise.resolve({}),
    };

    ecouteurDomibus = {
      arreteEcoute: () => {},
      ecoute: () => {},
      etat: () => '',
    };

    horodateur = {
      maintenant: () => '',
    };

    middleware = new MiddlewareFantaisie({});

    serveur = OOTS_FRANCE.creeServeur({
      adaptateurChiffrement,
      adaptateurDomibus,
      adaptateurEnvironnement,
      adaptateurFranceConnectPlus,
      adaptateurUUID,
      depotPointsAcces,
      ecouteurDomibus,
      horodateur,
      middleware,
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
    middleware: () => middleware,
    port,
  };
};

module.exports = serveurTest;
