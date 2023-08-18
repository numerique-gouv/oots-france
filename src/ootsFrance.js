const axios = require('axios');
const express = require('express');

const JustificatifEducation = require('./vues/justificatifEducation');
const RequeteJustificatifEducation = require('./vues/requeteJustificatifEducation');

const creeServeur = (config) => {
  const { adaptateurUUID } = config;
  let serveur;
  const app = express();

  app.get('/response/educationEvidence', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();
    const justificatif = new JustificatifEducation(uuid);

    reponse.set('Content-Type', 'text/xml');
    reponse.send(justificatif.enXML());
  });

  app.get('/request/educationEvidence', (_requete, reponse) => {
    const uuid = adaptateurUUID.genereUUID();
    const requeteJustificatif = new RequeteJustificatifEducation(uuid);

    reponse.set('Content-Type', 'text/xml');
    reponse.send(requeteJustificatif.enXML());
  });

  app.get('/idTestMessage', (requete, reponse) => {
    const destinataire = 'oots_test_platform';

    axios.post(
      `${process.env.URL_BASE_DOMIBUS}/services/backend/submitMessage`,
      `
<soap:Envelope
  xmlns:soap="http://www.w3.org/2003/05/soap-envelope"
  xmlns:ns="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
  xmlns:_1="http://org.ecodex.backend/1_1/">

  <soap:Header>
    <ns:Messaging>
      <ns:UserMessage mpc="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/defaultMPC">
        <ns:PartyInfo>
          <ns:From>
            <ns:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator">${process.env.EXPEDITEUR_DOMIBUS}</ns:PartyId>
            <ns:Role>http://sdg.europa.eu/edelivery/gateway</ns:Role>
          </ns:From>
          <ns:To>
            <ns:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator">${destinataire}</ns:PartyId>
            <ns:Role>http://sdg.europa.eu/edelivery/gateway</ns:Role>
          </ns:To>
        </ns:PartyInfo>
        <ns:CollaborationInfo>
          <ns:Service type="urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0">QueryManager</ns:Service>
          <ns:Action>ExecuteQueryRequest</ns:Action>
        </ns:CollaborationInfo>
        <ns:MessageProperties>
          <ns:Property name="originalSender">urn:oasis:names:tc:ebcore:partyid-type:unregistered:C1</ns:Property>
          <ns:Property name="finalRecipient">urn:oasis:names:tc:ebcore:partyid-type:unregistered:C4</ns:Property>
        </ns:MessageProperties>
        <ns:PayloadInfo>
          <ns:PartInfo href="cid:message">
            <ns:PartProperties>
              <ns:Property name="MimeType">text/xml</ns:Property>
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
      <payload payloadId="cid:message" contentType="text/xml">
        <value>PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPGhlbGxvPndvcmxkPC9oZWxsbz4=</value>
      </payload>
    </_1:submitRequest>
  </soap:Body>
</soap:Envelope>
      `,
      { headers: { 'Content-Type': 'text/xml' } },
    )
      .then(({ data }) => reponse.send(data));
  });

  app.get('/', (_requete, reponse) => {
    reponse.status(504).send('Not Implemented Yet!');
  });

  const ecoute = (...args) => { serveur = app.listen(...args); };

  const arreteEcoute = () => serveur.close();

  return {
    arreteEcoute,
    ecoute,
  };
};

module.exports = { creeServeur };
