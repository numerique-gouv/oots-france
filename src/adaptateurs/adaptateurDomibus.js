const axios = require('axios');
const { XMLParser } = require('fast-xml-parser');

const { ErreurAbsenceReponseDestinataire } = require('../erreurs');
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
    );
  };

  const envoieMessageTest = (destinataire) => envoieMessage(
    '<?xml version="1.0" encoding="UTF-8"?>\n<hello>world</hello>',
    destinataire,
  );

  const envoieMessageRequete = (destinataire, idConversation) => {
    const uuid = adaptateurUUID.genereUUID();
    const horodatage = horodateur.maintenant();
    const requeteJustificatif = new RequeteJustificatifEducation(uuid, horodatage);

    return envoieMessage(requeteJustificatif.enXML(), destinataire, idConversation);
  };

  const urlRedirectionDepuisReponse = (identifiantConversation) => {
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

    const requeteMessage = (idMessage) => `
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:_1="http://eu.domibus.wsplugin/">
  <soap:Header/>
  <soap:Body>
    <_1:retrieveMessageRequest>
      <messageID>${idMessage}</messageID>
    </_1:retrieveMessageRequest>
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

          if (typeof idMessage !== 'undefined') {
            clearInterval(idInterval);
            axios.post(
              `${urlBase}/services/wsplugin/retrieveMessage`,
              requeteMessage(idMessage),
              { headers: { 'Content-Type': 'text/xml' } },
            )
              .then(({ data: d }) => {
                const messageReponseEncode = parser.parse(d)['soap:Envelope']['soap:Body']['ns4:retrieveMessageResponse'].payload.value;
                const messageReponseDecode = Buffer.from(messageReponseEncode, 'base64').toString('ascii');
                const urlRedirection = parser.parse(messageReponseDecode)['query:QueryResponse']['ns6:Exception']['rim:Slot']
                  .find((slot) => slot['@_name'] === 'PreviewLocation')['rim:SlotValue']['rim:Value'];

                resolve(urlRedirection);
              });
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
