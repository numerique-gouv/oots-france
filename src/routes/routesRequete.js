const express = require('express');

const pieceJustificative = require('../api/pieceJustificative');

const routesRequete = (config) => {
  const {
    adaptateurDomibus,
    adaptateurUUID,
    depotPointsAcces,
    depotRequeteurs,
    depotServicesCommuns,
    middleware,
    transmetteurPiecesJustificatives,
  } = config;

  const routes = express.Router();

  routes.get(
    '/pieceJustificative',
    middleware.verifieInterrupteurOOTS,
    middleware.verifieBeneficiaire,
    (requete, reponse) => {
      pieceJustificative(
        {
          adaptateurDomibus,
          adaptateurUUID,
          depotPointsAcces,
          depotRequeteurs,
          depotServicesCommuns,
          transmetteurPiecesJustificatives,
        },
        requete,
        reponse,
      );
    },
  );

  return routes;
};

module.exports = routesRequete;
