const express = require('express');

const diplomeSecondDegre = require('./api/diplomeSecondDegre');
const JustificatifEducation = require('./vues/justificatifEducation');
const RequeteJustificatifEducation = require('./vues/requeteJustificatifEducation');

const creeServeur = (config) => {
  const { adaptateurDomibus, adaptateurUUID } = config;
  let serveur;
  const app = express();

  app.get('/response/educationEvidence', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();
    const justificatif = new JustificatifEducation(uuid);

    reponse.set('Content-Type', 'text/xml');
    reponse.send(justificatif.enXML());
  });

  app.get('/messageRequeteJustificatif', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();
    const requeteJustificatif = new RequeteJustificatifEducation(uuid);

    reponse.set('Content-Type', 'text/xml');
    reponse.send(requeteJustificatif.enXML());
  });

  app.get('/requete/diplomeSecondDegre', (...args) => diplomeSecondDegre(adaptateurDomibus, adaptateurUUID, ...args));

  app.get('/idMessageTest', (_requete, reponse) => adaptateurDomibus
    .envoieMessageTest('oots_test_platform')
    .then(({ data }) => reponse.send(data)));

  app.get('/', (_requete, reponse) => {
    reponse.status(504).send('Not Implemented Yet!');
  });

  const ecoute = (...args) => { serveur = app.listen(...args); };

  const arreteEcoute = () => serveur.close();

  return {
    arreteEcoute,
    ecoute,
  };
};

module.exports = { creeServeur };
