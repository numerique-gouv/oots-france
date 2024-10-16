class ConstructeurEnveloppeSOAPRequete {
  constructor() {
    this.idPayload = 'cid:99999999-9999-9999-9999-999999999999@oots.eu';
    this.codeDemarche = '';
    this.requeteur = { id: '', nom: '' };
  }

  avecCodeDemarche(codeDemarche) {
    this.codeDemarche = codeDemarche;
    return this;
  }

  avecRequeteur({ id, nom }) {
    Object.assign(this.requeteur, { id, nom });
    return this;
  }

  construis() {
    const message = `
<?xml version="1.0" encoding="UTF-8"?>
<query:QueryRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
          xmlns:sdg="http://data.europa.eu/p4s"
          xmlns:xmime="http://www.w3.org/2005/05/xmlmime"
          xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
          xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
          xmlns:xlink="http://www.w3.org/1999/xlink"
          xmlns:xml="http://www.w3.org/XML/1998/namespace"
          xml:lang="EN"
          id="urn:uuid:766d83a5-f753-4926-9603-cc9280f7651c">

  <rim:Slot name="SpecificationIdentifier"><!-- … --></rim:Slot>
  <rim:Slot name="IssueDateTime"><!-- … --></rim:Slot>
  <rim:Slot name="Procedure">
    <rim:SlotValue xsi:type="rim:InternationalStringValueType">
      <rim:Value>
        <rim:LocalizedString xml:lang="EN"
          value="${this.codeDemarche}"/>
      </rim:Value>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="PossibilityForPreview"><!-- … --></rim:Slot>
  <rim:Slot name="ExplicitRequestGiven"><!-- … --></rim:Slot>
  <rim:Slot name="Requirements"><!-- … --></rim:Slot>
  <rim:Slot name="EvidenceRequester">
    <rim:SlotValue xsi:type="rim:CollectionValueType" collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
      <rim:Element xsi:type="rim:AnyValueType">
        <sdg:Agent>
          <sdg:Identifier schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR">${this.requeteur.id}</sdg:Identifier>
          <sdg:Name lang="FR">${this.requeteur.nom}</sdg:Name>
          <sdg:Classification>ER</sdg:Classification>
        </sdg:Agent>
      </rim:Element>
      <rim:Element xsi:type="rim:AnyValueType">
        <sdg:Agent>
          <sdg:Identifier schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR">OOTSFRANCE</sdg:Identifier>
          <sdg:Name lang="EN">OOTS-France Intermediary Platform</sdg:Name>
          <sdg:Classification>IP</sdg:Classification>
        </sdg:Agent>
      </rim:Element>
    </rim:SlotValue>
  </rim:Slot>
  <rim:Slot name="EvidenceProvider"><!-- … --></rim:Slot>
  <query:ResponseOption returnType="LeafClassWithRepositoryItem"/>
  <query:Query queryDefinition="DocumentQuery">
    <rim:Slot name="NaturalPerson"><!-- … --></rim:Slot>
    <rim:Slot name="EvidenceRequest"><!-- … --></rim:Slot>
  </query:Query>
</query:QueryRequest>
`;
    const messageBase64 = Buffer.from(message).toString('base64');

    return `
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Header>
    <eb:Messaging xmlns:eb="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/" xmlns:ns2="http://www.w3.org/2003/05/soap-envelope" ns2:mustUnderstand="true">
      <eb:UserMessage mpc="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/defaultMPC">
        <eb:MessageInfo>
          <eb:Timestamp>2023-11-10T15:26:33.000Z</eb:Timestamp>
          <eb:MessageId>7612ae3c-954d-4fc2-8031-efd139b1248a@resp.gov.si</eb:MessageId>
        </eb:MessageInfo>
        <eb:PartyInfo>
          <eb:From>
            <eb:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator">AP_SI_01</eb:PartyId>
            <eb:Role>http://sdg.europa.eu/edelivery/gateway</eb:Role>
          </eb:From>
          <eb:To>
            <eb:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator">AP_FR_01</eb:PartyId>
            <eb:Role>http://sdg.europa.eu/edelivery/gateway</eb:Role>
          </eb:To>
        </eb:PartyInfo>
        <eb:CollaborationInfo>
          <eb:Service type="urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0">QueryManager</eb:Service>
          <eb:Action>ExecuteQueryRequest</eb:Action>
          <eb:ConversationId>5fe50e16-d6b8-4005-b5ec-0ab097f34448</eb:ConversationId>
        </eb:CollaborationInfo>
        <eb:MessageProperties>
          <eb:Property name="finalRecipient" type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-evidence-provider">C1</eb:Property>
          <eb:Property name="originalSender" type="urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-evidence-requester">BR_SI_01</eb:Property>
        </eb:MessageProperties>
        <eb:PayloadInfo>
          <eb:PartInfo href="${this.idPayload}">
            <eb:PartProperties>
              <eb:Property name="MimeType">application/x-ebrs+xml</eb:Property>
            </eb:PartProperties>
          </eb:PartInfo>
        </eb:PayloadInfo>
      </eb:UserMessage>
    </eb:Messaging>
  </soap:Header>
  <soap:Body>
    <ns4:retrieveMessageResponse
      xmlns:xmime="http://www.w3.org/2005/05/xmlmime"
      xmlns:ns5="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
      xmlns:ns4="http://eu.domibus.wsplugin/">
      <payload payloadId="${this.idPayload}">
        <value>${messageBase64}</value>
      </payload>
    </ns4:retrieveMessageResponse>
  </soap:Body>
</soap:Envelope>
  `;
  }
}

module.exports = ConstructeurEnveloppeSOAPRequete;
