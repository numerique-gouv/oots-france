const express = require('express');

const diplomeSecondDegre = require('./api/diplomeSecondDegre');
const EnteteRequete = require('./ebms/enteteRequete');
const RequeteJustificatifEducation = require('./ebms/requeteJustificatifEducation');
const JustificatifEducation = require('./vues/justificatifEducation');

const creeServeur = (config) => {
  const { adaptateurDomibus, adaptateurUUID, horodateur } = config;
  let serveur;
  const app = express();

  app.get('/response/educationEvidence', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();
    const justificatif = new JustificatifEducation(uuid);

    reponse.set('Content-Type', 'text/xml');
    reponse.send(justificatif.enXML());
  });

  app.get('/ebms/messages/requeteJustificatif', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();
    const horodatage = horodateur.maintenant();
    const requeteJustificatif = new RequeteJustificatifEducation(uuid, horodatage);

    reponse.set('Content-Type', 'text/xml');
    reponse.send(requeteJustificatif.enXML());
  });

  app.get('/ebms/entetes/requeteJustificatif', (requete, reponse) => {
    const { destinataire } = requete.query;
    const idConversation = adaptateurUUID.genereUUID();
    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
    const idPayload = `cid:${adaptateurUUID.genereUUID()}@${suffixe}`;
    const enteteEBMS = new EnteteRequete(
      { adaptateurUUID, horodateur },
      { destinataire, idConversation, idPayload },
    );

    reponse.set('Content-Type', 'text/xml');
    reponse.send(enteteEBMS.enXML());
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
