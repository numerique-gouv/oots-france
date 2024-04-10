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
        ? `
<!DOCTYPE html>
<meta charset="utf-8" />
<title>OOTS-France</title>
<p>Utilisateur courant : ${infosUtilisateur.given_name} ${infosUtilisateur.family_name}</p>
<a href="/auth/fcplus/destructionSession">Déconnexion</a>
`
        : "Pas d'utilisateur courant";

      reponse.set('Content-Type', 'text/html');
      reponse.send(message);
    },
  );

  return routes;
};

module.exports = routesBase;
