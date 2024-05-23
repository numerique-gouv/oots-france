const express = require('express');

const routesBase = () => {
  const routes = express.Router();

  routes.get('/', (_requete, reponse) => {
    reponse.send('OOTS-France');
  });

  return routes;
};

module.exports = routesBase;
