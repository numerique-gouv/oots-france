const express = require('express');

const EnteteErreur = require('../ebms/enteteErreur');
const EnteteRequete = require('../ebms/enteteRequete');
const Fournisseur = require('../ebms/fournisseur');
const PointAcces = require('../ebms/pointAcces');
const ReponseErreur = require('../ebms/reponseErreur');
const ReponseVerificationSysteme = require('../ebms/reponseVerificationSysteme');
const RequeteJustificatif = require('../ebms/requeteJustificatif');

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
    const requeteJustificatif = new RequeteJustificatif(
      { adaptateurUUID, horodateur },
      {
        fournisseur: new Fournisseur({
          pointAcces: { id: 'unIdentifiant', typeId: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR' },
          descriptions: { FR: 'Un requêteur' },
        }),
      },
    );

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

  routes.get('/messages/reponseJustificatif', (requete, reponse) => {
    const reponseJustificatif = new ReponseVerificationSysteme({ adaptateurUUID, horodateur }, {
      destinataire: new PointAcces('unTypeIdentifiant', 'unIdentifiant'),
      idRequete: '12345678-1234-1234-1234-1234567890ab',
      idConversation: '12345',
    });
    reponse.set('Content-Type', 'text/xml');
    reponse.send(reponseJustificatif.corpsMessageEnXML());
  });

  return routes;
};

module.exports = routesEbms;
