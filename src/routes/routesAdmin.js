const express = require('express');

const routesAdmin = (config) => {
  const { ecouteurDomibus } = config;

  const routes = express.Router();

  routes.post('/arretEcouteDomibus', (_requete, reponse) => {
    ecouteurDomibus.arreteEcoute();
    reponse.send({ etatEcouteur: ecouteurDomibus.etat() });
  });

  routes.post('/demarrageEcouteDomibus', (_requete, reponse) => {
    ecouteurDomibus.ecoute();
    reponse.send({ etatEcouteur: ecouteurDomibus.etat() });
  });

  return routes;
};

module.exports = routesAdmin;
