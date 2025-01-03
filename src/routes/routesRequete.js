const express = require('express');

const pieceJustificative = require('../api/pieceJustificative');

const routesRequete = (config) => {
  const {
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    depotPointsAcces,
    depotRequeteurs,
    depotServicesCommuns,
    transmetteurPiecesJustificatives,
  } = config;

  const routes = express.Router();

  routes.get('/pieceJustificative', (requete, reponse) => {
    if (adaptateurEnvironnement.avecRequetePieceJustificative()) {
      const { beneficiaire } = requete.query;
      if (typeof beneficiaire === 'undefined' || beneficiaire === '') {
        reponse.status(422).send({ erreur: 'Le bénéficiaire doit être renseigné' });
      } else {
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
      }
    } else {
      reponse.status(501).send('Not Implemented Yet!');
    }
  });

  return routes;
};

module.exports = routesRequete;
