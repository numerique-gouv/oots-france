const express = require('express');

const routesAuth = (config) => {
  const {
    adaptateurChiffrement,
    adaptateurEnvironnement,
  } = config;

  const routes = express.Router();

  routes.get('/cles_publiques', (_requete, reponse) => {
    const { kty, n, e } = adaptateurEnvironnement.clePriveeJWK();
    const idClePublique = adaptateurChiffrement.cleHachage(n);

    const clePubliqueDansJWKSet = {
      keys: [{
        kid: idClePublique,
        use: 'enc',
        kty,
        e,
        n,
      }],
    };

    reponse.set('Content-Type', 'application/json');
    reponse.status(200)
      .send(clePubliqueDansJWKSet);
  });

  return routes;
};

module.exports = routesAuth;
