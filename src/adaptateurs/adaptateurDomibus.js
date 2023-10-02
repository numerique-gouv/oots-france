const axios = require('axios');
const { XMLParser } = require('fast-xml-parser');

const { ErreurAbsenceReponseDestinataire } = require('../erreurs');
const { requeteRecuperationMessage } = require('../domibus/recuperationMessage');
const ReponseEnvoiMessage = require('../domibus/reponseEnvoiMessage');
const ReponseRecuperationMessage = require('../domibus/reponseRecuperationMessage');
const entete = require('../ebms/entete');
const RequeteJustificatifEducation = require('../ebms/requeteJustificatifEducation');

const urlBase = process.env.URL_BASE_DOMIBUS;

const enveloppeSOAP = (config, donnees, message) => {
  const enteteEBMS = entete(config, donnees);
  const { idPayload } = donnees;
  const messageEnBase64 = Buffer.from(message).toString('base64');

  return `
<soap:Envelope
  xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  xmlns:ns="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
  xmlns:_1="http://eu.domibus.wsplugin/"
  xmlns:xm="http://www.w3.org/2005/05/xmlmime">

  <soap:Header>${enteteEBMS}</soap:Header>

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

const AdaptateurDomibus = (config) => {
  const { adaptateurUUID, horodateur } = config;

  const envoieMessage = (message, destinataire, idConversation) => {
    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
    const idPayload = `cid:${adaptateurUUID.genereUUID()}@${suffixe}`;
    const messageAEnvoyer = enveloppeSOAP(
      config,
      { destinataire, idConversation, idPayload },
      message,
    );

    return axios.post(
      `${urlBase}/services/wsplugin/submitMessage`,
      messageAEnvoyer,
      { headers: { 'Content-Type': 'text/xml' } },
    ).then(({ data }) => new ReponseEnvoiMessage(data));
  };

  const envoieMessageTest = (destinataire) => envoieMessage(
    '<?xml version="1.0" encoding="UTF-8"?>\n<hello>world</hello>',
    destinataire,
  );

  const envoieMessageRequete = (destinataire, idConversation) => {
    const uuid = adaptateurUUID.genereUUID();
    const horodatage = horodateur.maintenant();
    const requeteJustificatif = new RequeteJustificatifEducation(uuid, horodatage);

    return envoieMessage(requeteJustificatif.enXML(), destinataire, idConversation)
      .then((reponse) => reponse.idMessage());
  };

  const recupereMessage = (idMessage) => axios
    .post(
      `${urlBase}/services/wsplugin/retrieveMessage`,
      requeteRecuperationMessage(idMessage),
      { headers: { 'Content-Type': 'text/xml' } },
    )
    .then(({ data }) => new ReponseRecuperationMessage(data));

  const urlRedirectionDepuisReponse = (identifiantConversation, idMessageRenvoye) => {
    const requeteListeMessagesEnAttente = (idConversation) => `
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:_1="http://eu.domibus.wsplugin/">
  <soap:Header/>
  <soap:Body>
    <_1:listPendingMessagesRequest>
      <conversationId>${idConversation}</conversationId>
    </_1:listPendingMessagesRequest>
  </soap:Body>
</soap:Envelope>
     `;

    return new Promise((resolve, reject) => {
      let idInterval;

      const tenteRecuperationIdMessageSuivant = () => axios.post(
        `${urlBase}/services/wsplugin/listPendingMessages`,
        requeteListeMessagesEnAttente(identifiantConversation),
        { headers: { 'Content-Type': 'text/xml' } },
      )
        .then(({ data }) => {
          const parser = new XMLParser({ ignoreAttributes: false });
          const xml = parser.parse(data);
          const idMessage = xml['soap:Envelope']['soap:Body']['ns4:listPendingMessagesResponse'].messageID;

          if (typeof idMessage !== 'undefined' && idMessage !== idMessageRenvoye) {
            clearInterval(idInterval);
            recupereMessage(idMessage)
              .then((reponse) => resolve(reponse.urlRedirection()));
          }
        });

      idInterval = setInterval(tenteRecuperationIdMessageSuivant, 500);

      setTimeout(() => {
        clearInterval(idInterval);
        reject(new ErreurAbsenceReponseDestinataire('Le destinataire ne répond pas !'));
      }, 10_000);
    });
  };

  return {
    envoieMessageRequete,
    envoieMessageTest,
    urlRedirectionDepuisReponse,
  };
};

module.exports = AdaptateurDomibus;
