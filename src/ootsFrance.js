const express = require('express');

const pieceJustificative = require('./api/pieceJustificative');
const EnteteErreur = require('./ebms/enteteErreur');
const EnteteRequete = require('./ebms/enteteRequete');
const PointAcces = require('./ebms/pointAcces');
const ReponseErreur = require('./ebms/reponseErreur');
const RequeteJustificatif = require('./ebms/requeteJustificatif');

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

  app.post('/admin/arretEcouteDomibus', (_requete, reponse) => {
    ecouteurDomibus.arreteEcoute();
    reponse.send({ etatEcouteur: ecouteurDomibus.etat() });
  });

  app.post('/admin/demarrageEcouteDomibus', (_requete, reponse) => {
    ecouteurDomibus.ecoute();
    reponse.send({ etatEcouteur: ecouteurDomibus.etat() });
  });

  app.get('/auth/fcplus/connexion', (requete, reponse) => {
    const { code, state } = requete.query;
    if (typeof state === 'undefined' || state === '') {
      reponse.status(400).json({ erreur: "Paramètre 'state' absent de la requête" });
    } else if (typeof code === 'undefined' || code === '') {
      reponse.status(400).json({ erreur: "Paramètre 'code' absent de la requête" });
    } else {
      adaptateurFranceConnectPlus.recupereInfosUtilisateur(code)
        .then((infos) => reponse.json(infos))
        .catch((e) => reponse.status(502).json({
          erreur: `Échec authentification (${e.message})`,
        }));
    }
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

  app.get('/auth/cles_publiques', (_requete, reponse) => {
    const { kty, n, e } = adaptateurEnvironnement.clePriveeJWK();
    const idClePublique = adaptateurChiffrement.cleHachage(n);

    const clePubliqueDansJWKSet = {
      keys: [{
        kid: idClePublique,
        use: 'enc',
        kty,
        e,
        n,
      }],
    };

    reponse.set('Content-Type', 'application/json');
    reponse.status(200)
      .send(clePubliqueDansJWKSet);
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
