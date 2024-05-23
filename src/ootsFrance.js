const express = require('express');
const mustacheExpress = require('mustache-express');

const routesAdmin = require('./routes/routesAdmin');
const routesBase = require('./routes/routesBase');
const routesEbms = require('./routes/routesEbms');
const routesRequete = require('./routes/routesRequete');

const creeServeur = (config) => {
  const {
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    depotPointsAcces,
    ecouteurDomibus,
    horodateur,
  } = config;
  let serveur;
  const app = express();

  app.set('trust proxy', 1);

  app.set('views', `${__dirname}/vues`);
  app.set('view engine', 'mustache');
  app.engine('mustache', mustacheExpress());

  app.use('/admin', routesAdmin({ ecouteurDomibus }));

  app.use('/ebms', routesEbms({ adaptateurUUID, horodateur }));

  app.use('/requete', routesRequete({
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    depotPointsAcces,
  }));

  app.use('/', routesBase());

  const arreteEcoute = (suite) => serveur.close(suite);

  const ecoute = (...args) => { serveur = app.listen(...args); };

  const port = () => serveur.address().port;

  return {
    arreteEcoute,
    ecoute,
    port,
  };
};

module.exports = { creeServeur };
