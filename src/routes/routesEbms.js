const express = require('express');

const EnteteErreur = require('../ebms/enteteErreur');
const EnteteRequete = require('../ebms/enteteRequete');
const Fournisseur = require('../ebms/fournisseur');
const PersonnePhysique = require('../ebms/personnePhysique');
const PointAcces = require('../ebms/pointAcces');
const ReponseErreur = require('../ebms/reponseErreur');
const ReponseVerificationSysteme = require('../ebms/reponseVerificationSysteme');
const RequeteJustificatif = require('../ebms/requeteJustificatif');
const Requeteur = require('../ebms/requeteur');
const TypeJustificatif = require('../ebms/typeJustificatif');

const routesEbms = (config) => {
  const { adaptateurUUID, horodateur } = config;

  const routes = express.Router();

  const sersXMLEntete = (ClasseEntete, reponse) => {
    const destinataire = new PointAcces(
      process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS,
      process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS,
    );
    const idConversation = adaptateurUUID.genereUUID();
    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
    const idPayload = `cid:${adaptateurUUID.genereUUID()}@${suffixe}`;
    const enteteEBMS = new ClasseEntete(
      { adaptateurUUID, horodateur },
      { destinataire, idConversation, idPayload },
    );

    reponse.set('Content-Type', 'text/xml');
    reponse.send(enteteEBMS.enXML());
  };

  routes.get('/entetes/requeteJustificatif', (_, reponse) => sersXMLEntete(EnteteRequete, reponse));

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

  routes.get('/entetes/reponseErreur', (_, reponse) => sersXMLEntete(EnteteErreur, reponse));

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
    const beneficiaire = new PersonnePhysique({ dateNaissance: '1992-10-22', nom: 'Dupont', prenom: 'Jean' });
    const requeteur = new Requeteur({ id: '12345', nom: 'Un requêteur' });
    const typeJustificatif = new TypeJustificatif({
      id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/12345678-1234-1234-1234-1234567890ab',
      descriptions: { EN: 'Some Evidence Type' },
    });
    const reponseJustificatif = new ReponseVerificationSysteme({ adaptateurUUID, horodateur }, {
      beneficiaire,
      destinataire: new PointAcces('unTypeIdentifiant', 'unIdentifiant'),
      idRequete: '12345678-1234-1234-1234-1234567890ab',
      idConversation: '12345',
      requeteur,
      typeJustificatif,
    });
    reponse.set('Content-Type', 'text/xml');
    reponse.send(reponseJustificatif.corpsMessageEnXML());
  });

  return routes;
};

module.exports = routesEbms;
