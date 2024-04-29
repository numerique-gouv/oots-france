const express = require('express');

const routesBase = (config) => {
  const { middleware } = config;
  const routes = express.Router();

  routes.get(
    '/',
    (...args) => middleware.renseigneUtilisateurCourant(...args),
    (requete, reponse) => {
      const infosUtilisateur = requete.utilisateurCourant;
      reponse.render('pageAccueil', { infosUtilisateur });
    },
  );

  return routes;
};

module.exports = routesBase;
