const express = require('express');

const EnteteErreur = require('../ebms/enteteErreur');
const EnteteRequete = require('../ebms/enteteRequete');
const ReponseErreur = require('../ebms/reponseErreur');
const RequeteJustificatif = require('../ebms/requeteJustificatif');
const PointAcces = require('../ebms/pointAcces');

const routesEbms = (config) => {
  const { adaptateurUUID, horodateur } = config;

  const routes = express.Router();

  routes.get('/entetes/requeteJustificatif', (requete, reponse) => {
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

  routes.get('/messages/requeteJustificatif', (_requete, reponse) => {
    const requeteJustificatif = new RequeteJustificatif({ adaptateurUUID, horodateur });

    reponse.set('Content-Type', 'text/xml');
    reponse.send(requeteJustificatif.corpsMessageEnXML());
  });

  routes.get('/entetes/reponseErreur', (requete, reponse) => {
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

  routes.get('/messages/reponseErreur', (requete, reponse) => {
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

  return routes;
};

module.exports = routesEbms;
