const cookieSession = require('cookie-session');
const express = require('express');

const pieceJustificative = require('./api/pieceJustificative');
const routesAdmin = require('./routes/routesAdmin');
const routesAuth = require('./routes/routesAuth');
const routesEbms = require('./routes/routesEbms');

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
  } = config;
  let serveur;
  const app = express();

  app.use(cookieSession({
    maxAge: 15 * 60 * 1000,
    name: 'jeton',
    sameSite: true,
    secret: adaptateurEnvironnement.secretJetonSession(),
    secure: adaptateurEnvironnement.avecEnvoiCookieSurHTTP(),
  }));

  app.use('/admin', routesAdmin({ ecouteurDomibus }));

  app.use('/auth', routesAuth({
    adaptateurChiffrement,
    adaptateurEnvironnement,
    adaptateurFranceConnectPlus,
  }));

  app.use('/ebms', routesEbms({ adaptateurUUID, horodateur }));

  app.get('/requete/pieceJustificative', (requete, reponse) => {
    if (adaptateurEnvironnement.avecRequetePieceJustificative()) {
      pieceJustificative({ adaptateurDomibus, adaptateurUUID, depotPointsAcces }, requete, reponse);
    } else {
      reponse.status(501).send('Not Implemented Yet!');
    }
  });

  app.get('/', (requete, reponse) => {
    adaptateurChiffrement.verifieJeton(requete.session.jeton)
      .then((jeton) => (jeton
        ? `Utilisateur courant : ${jeton.given_name} ${jeton.family_name}`
        : "Pas d'utilisateur courant"))
      .then((message) => reponse.send(message));
  });

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
