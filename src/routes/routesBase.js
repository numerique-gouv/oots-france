const express = require('express');

const routesBase = (config) => {
  const {
    adaptateurEnvironnement,
    middleware,
  } = config;

  const routes = express.Router();

  routes.get(
    '/',
    (...args) => middleware.renseigneUtilisateurCourant(...args),
    (requete, reponse) => {
      const infosUtilisateur = requete.utilisateurCourant;
      const avecConnexionFCPlus = adaptateurEnvironnement.avecConnexionFCPlus();
      reponse.render('pageAccueil', {
        infosUtilisateur,
        avecConnexionFCPlus,
      });
    },
  );

  return routes;
};

module.exports = routesBase;
