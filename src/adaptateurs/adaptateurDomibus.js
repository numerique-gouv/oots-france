const axios = require('axios');
const { XMLParser } = require('fast-xml-parser');

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

  const envoieMessageRequete = (destinataire, idConversation) => envoieMessage(
    `<?xml version="1.0" encoding="UTF-8"?>
<query:QueryRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
          xmlns:sdg="http://data.europa.eu/p4s"
          xmlns:xmime="http://www.w3.org/2005/05/xmlmime"
          xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
          xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
          xmlns:xlink="http://www.w3.org/1999/xlink"
          xmlns:xml="http://www.w3.org/XML/1998/namespace"
          xml:lang="EN"
          id="urn:uuid:${adaptateurUUID.genereUUID()}">

  <rim:Slot name="SpecificationIdentifier">
    <rim:SlotValue xsi:type="rim:StringValueType">
      <rim:Value>oots-edm:v1.0</rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="IssueDateTime">
    <rim:SlotValue xsi:type="rim:DateTimeValueType">
      <rim:Value>${new Date().toISOString()}</rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="Procedure">
    <rim:SlotValue xsi:type="rim:InternationalStringValueType">
      <rim:Value>
        <rim:LocalizedString xml:lang="EN"
          value="T2"/>
      </rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="PossibilityForPreview">
    <rim:SlotValue xsi:type="rim:BooleanValueType">
      <rim:Value>true</rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="ExplicitRequestGiven">
    <rim:SlotValue xsi:type="rim:BooleanValueType">
      <rim:Value>true</rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="Requirements">
    <rim:SlotValue xsi:type="rim:CollectionValueType"
      collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
      <rim:Element xsi:type="rim:AnyValueType">
        <sdg:Requirement>
          <sdg:Identifier>https://sr.oots.tech.ec.europa.eu/requirements/17015504-5140-3659-8d83-9838400e2e14</sdg:Identifier>
          <sdg:Name lang="EN">Proof of tertiary education diploma/certificate/degree</sdg:Name>
        </sdg:Requirement>
      </rim:Element>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="EvidenceRequester">
    <rim:SlotValue xsi:type="rim:CollectionValueType">
      <rim:Element xsi:type="rim:AnyValueType">
        <sdg:Agent>
          <sdg:Identifier schemeID="urn:cef.eu:names:identifier:EAS:0096">DK22233223</sdg:Identifier>
          <sdg:Name lang="EN">Denmark University Portal</sdg:Name>
          <sdg:Address>
            <sdg:FullAddress>Prince Street 15, 1050 Copenhagen, Denmark</sdg:FullAddress>
            <sdg:LocatorDesignator>15</sdg:LocatorDesignator>
            <sdg:PostCode>1050</sdg:PostCode>
            <sdg:PostCityName>Copenhagen</sdg:PostCityName>
            <sdg:Thoroughfare>Prince Street</sdg:Thoroughfare>
            <sdg:AdminUnitLevel1>DK</sdg:AdminUnitLevel1>
            <sdg:AdminUnitLevel2>DK011</sdg:AdminUnitLevel2>
          </sdg:Address>
          <sdg:Classification>ER</sdg:Classification>
        </sdg:Agent>
      </rim:Element>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="EvidenceProvider">
    <rim:SlotValue xsi:type="rim:AnyValueType">
      <sdg:Agent>
        <!--sdg:Identifier schemeID="urn:cef.eu:names:identifier:EAS:9930">DE73524311</sdg:Identifier-->
        <sdg:Identifier schemeID="urn:cef.eu:names:identifier:EAS:9930">220</sdg:Identifier>
        <sdg:Name lang="EN">Višja strokovna šola</sdg:Name>
      </sdg:Agent>
    </rim:SlotValue>
  </rim:Slot>
  <query:ResponseOption returnType="LeafClassWithRepositoryItem"/>
  <query:Query queryDefinition="DocumentQuery">
    <rim:Slot name="NaturalPerson">
      <rim:SlotValue xsi:type="rim:AnyValueType">
        <sdg:Person>
          <sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>
          <sdg:Identifier schemeID="eidas">DK/DE/123123123</sdg:Identifier>
          <sdg:FamilyName>Smith</sdg:FamilyName>
          <sdg:GivenName>John</sdg:GivenName>
          <sdg:DateOfBirth>1970-03-01</sdg:DateOfBirth>
          <sdg:BirthName>John Doepidis</sdg:BirthName>
          <sdg:PlaceOfBirth>Hamburg, Germany</sdg:PlaceOfBirth>
          <sdg:CurrentAddress>
            <sdg:FullAddress>Refshalevej 96, 1432 København, Denmark</sdg:FullAddress>
            <sdg:LocatorDesignator>96</sdg:LocatorDesignator>
            <sdg:PostCode>1432</sdg:PostCode>
            <sdg:PostCityName>København</sdg:PostCityName>
            <sdg:Thoroughfare>Refshalevej</sdg:Thoroughfare>
            <sdg:AdminUnitLevel1>DK</sdg:AdminUnitLevel1>
            <sdg:AdminUnitLevel2>DK011</sdg:AdminUnitLevel2>
          </sdg:CurrentAddress>
          <sdg:Gender>Male</sdg:Gender>
          <sdg:SectorSpecificAttribute>
            <sdg:AttributeName>IBAN</sdg:AttributeName>
            <sdg:AttributeURI>http://eidas.europa.eu/attributes/naturalperson/banking/IBAN</sdg:AttributeURI>
            <sdg:AttributeValue>DE02500105170137075032</sdg:AttributeValue>
          </sdg:SectorSpecificAttribute>
          <sdg:SectorSpecificAttribute>
            <sdg:AttributeName>BIC</sdg:AttributeName>
            <sdg:AttributeURI>http://eidas.europa.eu/attributes/naturalperson/banking/BIC</sdg:AttributeURI>
            <sdg:AttributeValue>INGDDEFFYYY</sdg:AttributeValue>
          </sdg:SectorSpecificAttribute>
        </sdg:Person>
      </rim:SlotValue>
    </rim:Slot>
    <rim:Slot name="EvidenceRequest">
      <rim:SlotValue xsi:type="rim:AnyValueType">
        <sdg:DataServiceEvidenceType xmlns="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0">
          <!--sdg:Identifier>2af27699-f131-4411-8fdb-9e8cd4e8bded</sdg:Identifier-->
          <sdg:Identifier>936f3aa4-afc9-4363-ad19-9579cd09ef8e</sdg:Identifier>
          <!--sdg:EvidenceTypeClassification>https://sr.oots.tech.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e</sdg:EvidenceTypeClassification-->
          <sdg:EvidenceTypeClassification>https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/SI/e2aa2284-501d-344b-b49c-589c50484c14</sdg:EvidenceTypeClassification>
          <sdg:Title lang="EN">Diploma</sdg:Title>
          <sdg:DistributedAs>
            <sdg:Format>application/xml</sdg:Format>
          </sdg:DistributedAs>
        </sdg:DataServiceEvidenceType>
      </rim:SlotValue>
    </rim:Slot>
  </query:Query>
</query:QueryRequest>`,
    destinataire,
    idConversation,
  );

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
