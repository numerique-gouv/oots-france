const express = require('express');

const routesBase = (config) => {
  const { middleware } = config;
  const routes = express.Router();

  routes.get(
    '/',
    (...args) => middleware.renseigneUtilisateurCourant(...args),
    (requete, reponse) => {
      const infosUtilisateur = requete.utilisateurCourant;
      const message = infosUtilisateur
        ? `Utilisateur courant : ${infosUtilisateur.given_name} ${infosUtilisateur.family_name}`
        : "Pas d'utilisateur courant";

      reponse.send(message);
    },
  );

  return routes;
};

module.exports = routesBase;
