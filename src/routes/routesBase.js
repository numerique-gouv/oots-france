const express = require('express');

const routesBase = (config) => {
  const { adaptateurChiffrement } = config;
  const routes = express.Router();

  routes.get('/', (requete, reponse) => {
    adaptateurChiffrement.verifieJeton(requete.session.jeton)
      .then((jeton) => (jeton
        ? `Utilisateur courant : ${jeton.given_name} ${jeton.family_name}`
        : "Pas d'utilisateur courant"))
      .then((message) => reponse.send(message));
  });

  return routes;
};

module.exports = routesBase;
