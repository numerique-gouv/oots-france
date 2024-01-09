const express = require('express');

const pieceJustificative = require('./api/pieceJustificative');
const EnteteErreur = require('./ebms/enteteErreur');
const EnteteRequete = require('./ebms/enteteRequete');
const PointAcces = require('./ebms/pointAcces');
const ReponseErreur = require('./ebms/reponseErreur');
const RequeteJustificatif = require('./ebms/requeteJustificatif');

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

  app.post('/admin/arretEcouteDomibus', (_requete, reponse) => {
    ecouteurDomibus.arreteEcoute();
    reponse.send({ etatEcouteur: ecouteurDomibus.etat() });
  });

  app.post('/admin/demarrageEcouteDomibus', (_requete, reponse) => {
    ecouteurDomibus.ecoute();
    reponse.send({ etatEcouteur: ecouteurDomibus.etat() });
  });

  app.get('/ebms/entetes/requeteJustificatif', (requete, reponse) => {
    const { idDestinataire, typeIdentifiant } = requete.query;
    const destinataire = new PointAcces(idDestinataire, typeIdentifiant);
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
    reponse.send(requeteJustificatif.corpsMessageEnXML());
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
    const reponseErreur = new ReponseErreur({ adaptateurUUID, horodateur }, {
      idRequete: adaptateurUUID.genereUUID(),
      exception: {
        type: 'rs:ObjectNotFoundExceptionType',
        message: 'Object not found',
        severite: 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error',
        code: 'EDM:ERR:0004',
      },
    });
    reponse.set('Content-Type', 'text/xml');
    reponse.send(reponseErreur.corpsMessageEnXML());
  });

  app.get('/requete/pieceJustificative', (requete, reponse) => {
    if (adaptateurEnvironnement.avecRequetePieceJustificative()) {
      pieceJustificative({ adaptateurDomibus, adaptateurUUID, depotPointsAcces }, requete, reponse);
    } else {
      reponse.status(501).send('Not Implemented Yet!');
    }
  });

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
