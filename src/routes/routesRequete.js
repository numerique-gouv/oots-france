const express = require('express');

const pieceJustificative = require('../api/pieceJustificative');

const routesRequete = (config) => {
  const {
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    depotPointsAcces,
    depotServicesCommuns,
  } = config;

  const routes = express.Router();

  routes.get('/pieceJustificative', (requete, reponse) => {
    if (adaptateurEnvironnement.avecRequetePieceJustificative()) {
      pieceJustificative(
        {
          adaptateurDomibus,
          adaptateurUUID,
          depotPointsAcces,
          depotServicesCommuns,
        },
        requete,
        reponse,
      );
    } else {
      reponse.status(501).send('Not Implemented Yet!');
    }
  });

  return routes;
};

module.exports = routesRequete;
