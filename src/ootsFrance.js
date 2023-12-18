const express = require('express');

const pieceJustificative = require('./api/pieceJustificative');
const EnteteErreur = require('./ebms/enteteErreur');
const EnteteRequete = require('./ebms/enteteRequete');
const ReponseErreur = require('./ebms/reponseErreur');
const RequeteJustificatif = require('./ebms/requeteJustificatif');
const JustificatifEducation = require('./vues/justificatifEducation');

const creeServeur = (config) => {
  const {
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    ecouteurDomibus,
    horodateur,
  } = config;
  let serveur;
  const app = express();

  app.get('/response/educationEvidence', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();
    const justificatif = new JustificatifEducation(uuid);

    reponse.set('Content-Type', 'text/xml');
    reponse.send(justificatif.enXML());
  });

  app.post('/admin/arretEcouteDomibus', (_requete, reponse) => {
    ecouteurDomibus.arreteEcoute();
    reponse.send({ etatEcouteur: ecouteurDomibus.etat() });
  });

  app.post('/admin/demarrageEcouteDomibus', (_requete, reponse) => {
    ecouteurDomibus.ecoute();
    reponse.send({ etatEcouteur: ecouteurDomibus.etat() });
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

  app.get('/ebms/messages/requeteJustificatif', (_requete, reponse) => {
    const requeteJustificatif = new RequeteJustificatif({ adaptateurUUID, horodateur });

    reponse.set('Content-Type', 'text/xml');
    reponse.send(requeteJustificatif.enXML());
  });

  app.get('/ebms/entetes/reponseErreur', (requete, reponse) => {
    const { destinataire } = requete.query;
    const idConversation = adaptateurUUID.genereUUID();
    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
    const idPayload = `cid:${adaptateurUUID.genereUUID()}@${suffixe}`;
    const enteteEBMS = new EnteteErreur(
      { adaptateurUUID, horodateur },
      { destinataire, idConversation, idPayload },
    );

    reponse.set('Content-Type', 'text/xml');
    reponse.send(enteteEBMS.enXML());
  });

  app.get('/ebms/messages/reponseErreur', (requete, reponse) => {
    const reponseErreur = new ReponseErreur({
      idRequete: adaptateurUUID.genereUUID(),
      exception: {
        type: 'rs:ObjectNotFoundExceptionType',
        message: 'Object not found',
        severite: 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error',
        code: 'EDM:ERR:0004',
      },
    }, { adaptateurUUID, horodateur });
    reponse.set('Content-Type', 'text/xml');
    reponse.send(reponseErreur.enXML());
  });

  app.get('/requete/pieceJustificative', (requete, reponse) => {
    if (adaptateurEnvironnement.avecRequetePieceJustificative()) {
      pieceJustificative(adaptateurDomibus, adaptateurUUID, requete, reponse);
    } else {
      reponse.status(501).send('Not Implemented Yet!');
    }
  });

  app.get('/idMessageTest', (_requete, reponse) => adaptateurDomibus
    .envoieMessageTest('oots_test_platform')
    .then(({ data }) => reponse.send(data)));

  app.get('/', (_requete, reponse) => {
    reponse.status(501).send('Not Implemented Yet!');
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
