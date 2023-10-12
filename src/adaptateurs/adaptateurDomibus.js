const axios = require('axios');
const EventEmitter = require('node:events');

const { ErreurAbsenceReponseDestinataire, ErreurAucunMessageDomibusRecu } = require('../erreurs');
const { requeteListeMessagesEnAttente, requeteRecuperationMessage } = require('../domibus/requetes');
const ReponseEnvoiMessage = require('../domibus/reponseEnvoiMessage');
const ReponseRecuperationMessage = require('../domibus/reponseRecuperationMessage');
const ReponseRequeteListeMessagesEnAttente = require('../domibus/reponseRequeteListeMessagesEnAttente');
const Entete = require('../ebms/entete');
const EnteteReponse = require('../ebms/enteteReponse');
const EnteteRequete = require('../ebms/enteteRequete');
const RequeteJustificatifEducation = require('../ebms/requeteJustificatifEducation');

const urlBase = process.env.URL_BASE_DOMIBUS;
const REPONSE_REDIRECTION_PREVISUALISATION = 'reponseRedirectionPrevisualisation';
const REPONSE_SUCCES = 'reponseSucces';

const enveloppeSOAP = (config, idPayload, enteteEBMS, message) => {
  const messageEnBase64 = Buffer.from(message).toString('base64');

  return `
<soap:Envelope
  xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  xmlns:ns="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
  xmlns:_1="http://eu.domibus.wsplugin/"
  xmlns:xm="http://www.w3.org/2005/05/xmlmime">

  <soap:Header>${enteteEBMS.enXML()}</soap:Header>

  <soap:Body>
    <_1:submitRequest>
      <bodyload>
        <value>cid:bodyload</value>
      </bodyload>
      <payload payloadId="${idPayload}" contentType="application/x-ebrs+xml">
        <value>${messageEnBase64}</value>
      </payload>
    </_1:submitRequest>
  </soap:Body>
</soap:Envelope>
  `;
};

const AdaptateurDomibus = (config = {}) => {
  const { adaptateurUUID, horodateur } = config;
  const annonceur = new EventEmitter();

  const envoieReponse = (message, destinataire, idConversation) => {
    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
    const idPayload = `cid:${adaptateurUUID.genereUUID()}@${suffixe}`;
    const enteteEBMS = new EnteteReponse(config, { destinataire, idConversation, idPayload });
    const messageAEnvoyer = enveloppeSOAP(
      config,
      idPayload,
      enteteEBMS,
      message,
    );

    return axios.post(
      `${urlBase}/services/wsplugin/submitMessage`,
      messageAEnvoyer,
      { headers: { 'Content-Type': 'text/xml' } },
    ).then(({ data }) => new ReponseEnvoiMessage(data));
  };

  const envoieRequete = (message, destinataire, idConversation) => {
    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
    const idPayload = `cid:${adaptateurUUID.genereUUID()}@${suffixe}`;
    const enteteEBMS = new EnteteRequete(config, { destinataire, idConversation, idPayload });
    const messageAEnvoyer = enveloppeSOAP(
      config,
      idPayload,
      enteteEBMS,
      message,
    );

    return axios.post(
      `${urlBase}/services/wsplugin/submitMessage`,
      messageAEnvoyer,
      { headers: { 'Content-Type': 'text/xml' } },
    ).then(({ data }) => new ReponseEnvoiMessage(data));
  };

  const ecoute = () => {
    const recupereIdMessageSuivant = (identifiantConversation) => axios.post(
      `${urlBase}/services/wsplugin/listPendingMessages`,
      requeteListeMessagesEnAttente(identifiantConversation),
      { headers: { 'Content-Type': 'text/xml' } },
    )
      .then(({ data }) => new ReponseRequeteListeMessagesEnAttente(data))
      .then((reponse) => {
        if (reponse.messageEnAttente()) { return reponse.idMessageSuivant(); }
        return Promise.reject(new ErreurAucunMessageDomibusRecu());
      });

    const recupereMessage = (idMessage) => axios.post(
      `${urlBase}/services/wsplugin/retrieveMessage`,
      requeteRecuperationMessage(idMessage),
      { headers: { 'Content-Type': 'text/xml' } },
    )
      .then(({ data }) => new ReponseRecuperationMessage(data));

    const repondsA = (requete) => {
      envoieReponse('', 'AP_FR_01', requete.idConversation());
    };

    const traiteMessageSuivant = () => recupereIdMessageSuivant()
      .then((idMessage) => recupereMessage(idMessage))
      .then((message) => {
        if (message.action() === Entete.REPONSE_ERREUR) {
          annonceur.emit(REPONSE_REDIRECTION_PREVISUALISATION, message);
        } else if (message.action() === Entete.EXECUTION_REPONSE) {
          annonceur.emit(REPONSE_SUCCES, message);
        } else if (message.action() === Entete.EXECUTION_REQUETE) {
          repondsA(message);
        }
      })
      .catch((e) => {
        if (!(e instanceof ErreurAucunMessageDomibusRecu)) { throw e; }
      });

    setInterval(traiteMessageSuivant, 300);
  };

  const envoieMessageTest = (destinataire) => envoieRequete(
    '<?xml version="1.0" encoding="UTF-8"?>\n<hello>world</hello>',
    destinataire,
  );

  const envoieMessageRequete = (destinataire, idConversation) => {
    const uuid = adaptateurUUID.genereUUID();
    const horodatage = horodateur.maintenant();
    const requeteJustificatif = new RequeteJustificatifEducation(uuid, horodatage);

    return envoieRequete(requeteJustificatif.enXML(), destinataire, idConversation)
      .then((reponse) => reponse.idMessage());
  };

  const urlRedirectionDepuisReponse = (idConversation) => new Promise(
    (resolve, reject) => {
      annonceur.on(REPONSE_REDIRECTION_PREVISUALISATION, (reponse) => {
        if (idConversation === reponse.idConversation()) {
          resolve(reponse.urlRedirection());
        }
      });

      setTimeout(() => {
        reject(new ErreurAbsenceReponseDestinataire('aucune URL de redirection reçue'));
      }, 10_000);
    },
  );

  const pieceJustificativeDepuisReponse = (idConversation) => new Promise(
    (resolve, reject) => {
      annonceur.on(REPONSE_SUCCES, (reponse) => {
        if (idConversation === reponse.idConversation()) {
          resolve('Une pièce');
        }
      });

      setTimeout(() => {
        reject(new ErreurAbsenceReponseDestinataire('aucune pièce justificative reçue'));
      }, 10_000);
    },
  );

  return {
    ecoute,
    envoieMessageRequete,
    envoieMessageTest,
    pieceJustificativeDepuisReponse,
    urlRedirectionDepuisReponse,
  };
};

module.exports = AdaptateurDomibus;
