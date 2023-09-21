const axios = require('axios');
const { XMLParser } = require('fast-xml-parser');

const RequeteJustificatifEducation = require('../vues/requeteJustificatifEducation');

const urlBase = process.env.URL_BASE_DOMIBUS;
const expediteur = process.env.EXPEDITEUR_DOMIBUS;

const AdaptateurDomibus = (config) => {
  const { adaptateurUUID } = config;

  const envoieMessage = (message, destinataire, idConversation) => {
    const messageEnBase64 = Buffer.from(message).toString('base64');
    const baliseIdConversation = (typeof idConversation !== 'undefined')
      ? `<ns:ConversationId>${idConversation}</ns:ConversationId>`
      : '';

    const messageAEnvoyer = `
<soap:Envelope
  xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  xmlns:ns="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
  xmlns:_1="http://eu.domibus.wsplugin/"
  xmlns:xm="http://www.w3.org/2005/05/xmlmime">

  <soap:Header>
    <ns:Messaging>
      <ns:UserMessage mpc="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/defaultMPC">
        <ns:PartyInfo>
          <ns:From>
            <ns:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator">
              ${expediteur}
            </ns:PartyId>
            <ns:Role>http://sdg.europa.eu/edelivery/gateway</ns:Role>
          </ns:From>
          <ns:To>
            <ns:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator">
              ${destinataire}
            </ns:PartyId>
            <ns:Role>http://sdg.europa.eu/edelivery/gateway</ns:Role>
          </ns:To>
        </ns:PartyInfo>
        <ns:CollaborationInfo>
          <ns:Service type="urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0">QueryManager</ns:Service>
          <ns:Action>ExecuteQueryRequest</ns:Action>
          ${baliseIdConversation}
        </ns:CollaborationInfo>
        <ns:MessageProperties>
          <ns:Property name="originalSender">urn:oasis:names:tc:ebcore:partyid-type:unregistered:C1</ns:Property>
          <ns:Property name="finalRecipient">urn:oasis:names:tc:ebcore:partyid-type:unregistered:C4</ns:Property>
        </ns:MessageProperties>
        <ns:PayloadInfo>
           <ns:PartInfo href="cid:regrep@oots.eu">
              <ns:PartProperties>
                 <ns:Property name="MimeType">application/x-ebrs+xml</ns:Property>
                 <ns:Property name="PayloadName">request.xml</ns:Property>
              </ns:PartProperties>
           </ns:PartInfo>
        </ns:PayloadInfo>
      </ns:UserMessage>
    </ns:Messaging>
  </soap:Header>

  <soap:Body>
    <_1:submitRequest>
      <bodyload>
        <value>cid:bodyload</value>
      </bodyload>
      <payload payloadId="cid:regrep@oots.eu" contentType="application/x-ebrs+xml">
        <value>${messageEnBase64}</value>
      </payload>
    </_1:submitRequest>
  </soap:Body>
</soap:Envelope>
      `;

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
    const requeteJustificatif = new RequeteJustificatifEducation(uuid);

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

    return new Promise((resolve) => {
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
    });
  };

  return {
    envoieMessageRequete,
    envoieMessageTest,
    urlRedirectionDepuisReponse,
  };
};

module.exports = AdaptateurDomibus;
