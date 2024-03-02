const cookieSession = require('cookie-session');
const express = require('express');

const routesAdmin = require('./routes/routesAdmin');
const routesAuth = require('./routes/routesAuth');
const routesBase = require('./routes/routesBase');
const routesEbms = require('./routes/routesEbms');
const routesRequete = require('./routes/routesRequete');

const creeServeur = (config) => {
  const {
    adaptateurChiffrement,
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurFranceConnectPlus,
    adaptateurUUID,
    depotPointsAcces,
    ecouteurDomibus,
    horodateur,
    middleware,
  } = config;
  let serveur;
  const app = express();

  app.set('trust proxy', 1);

  app.use(cookieSession({
    maxAge: 15 * 60 * 1000,
    name: 'jeton',
    sameSite: true,
    secret: adaptateurEnvironnement.secretJetonSession(),
    secure: !adaptateurEnvironnement.avecEnvoiCookieSurHTTP(),
  }));

  app.use('/admin', routesAdmin({ ecouteurDomibus }));

  app.use('/auth', routesAuth({
    adaptateurChiffrement,
    adaptateurEnvironnement,
    adaptateurFranceConnectPlus,
  }));

  app.use('/ebms', routesEbms({ adaptateurUUID, horodateur }));

  app.use('/requete', routesRequete({
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    depotPointsAcces,
  }));

  app.use('/', routesBase({ middleware }));

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
