const express = require('express');
const ModelePageAccueil = require('../views/modelePageAccueil');

const routesBase = (config) => {
  const { middleware } = config;
  const routes = express.Router();

  routes.get(
    '/',
    (...args) => middleware.renseigneUtilisateurCourant(...args),
    (requete, reponse) => {
      const infosUtilisateur = requete.utilisateurCourant;
      reponse.set('Content-Type', 'text/html');
      reponse.send(new ModelePageAccueil(infosUtilisateur).enHTML());
    },
  );

  return routes;
};

module.exports = routesBase;
