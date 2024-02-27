const express = require('express');

const routesBase = (config) => {
  const { adaptateurChiffrement, adaptateurEnvironnement } = config;
  const routes = express.Router();

  routes.get('/', (requete, reponse) => {
    const secret = adaptateurEnvironnement.secretJetonSession();
    adaptateurChiffrement.verifieJeton(requete.session.jeton, secret)
      .then((jeton) => (jeton
        ? `Utilisateur courant : ${jeton.given_name} ${jeton.family_name}`
        : "Pas d'utilisateur courant"))
      .then((message) => reponse.send(message));
  });

  return routes;
};

module.exports = routesBase;
