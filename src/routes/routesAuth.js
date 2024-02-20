const express = require('express');

const connexionFCPlus = require('../api/connexionFCPlus');

const routesAuth = (config) => {
  const { adaptateurChiffrement, adaptateurEnvironnement, adaptateurFranceConnectPlus } = config;

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

  routes.get('/fcplus/connexion', (requete, reponse) => {
    const { code, state } = requete.query;
    if (typeof state === 'undefined' || state === '') {
      reponse.status(400).json({ erreur: "Paramètre 'state' absent de la requête" });
    } else if (typeof code === 'undefined' || code === '') {
      reponse.status(400).json({ erreur: "Paramètre 'code' absent de la requête" });
    } else {
      connexionFCPlus(
        { adaptateurChiffrement, adaptateurFranceConnectPlus },
        code,
        requete,
        reponse,
      );
    }
  });

  return routes;
};

module.exports = routesAuth;
