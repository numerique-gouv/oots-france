class ConstructeurEnveloppeSOAPAvecPieceJointe {
  constructor() {
    this.idPayload = 'cid:99999999-9999-9999-9999-999999999999@oots.eu';
    this.idPieceJointe = 'cid:11111111-1111-1111-1111-111111111111@pdf.oots.eu';
    this.typeMimePieceJointe = 'application/pdf';
    this.contenuPieceJointe = '';
  }

  avecPieceJointe(id, typeMime, contenu) {
    this.idPieceJointe = id;
    this.typeMimePieceJointe = typeMime;
    this.contenuPieceJointe = contenu;

    return this;
  }

  construis() {
    const message = `<query:QueryResponse
        xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
        xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
        xmlns:ns7="http://www.w3.org/1999/xlink"
        status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success"
        requestId="urn:uuid:766d83a5-f753-4926-9603-cc9280f7651c">

  <rim:Slot name="SpecificationIdentifier"><!-- … --></rim:Slot>
  <rim:Slot name="EvidenceResponseIdentifier"><!-- … --></rim:Slot>
  <rim:Slot name="IssueDateTime"><!-- … --></rim:Slot>
  <rim:Slot name="EvidenceProvider"><!-- … --></rim:Slot>
  <rim:Slot name="EvidenceRequester"><!-- … --></rim:Slot>
  <rim:RegistryObjectList>
    <rim:RegistryObject xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="rim:ExtrinsicObjectType" id="urn:uuid:0c37ed98-5774-407a-a056-21eeffe66712">
      <rim:Slot name="EvidenceMetadata"><!-- … --></rim:Slot>
      <rim:RepositoryItemRef ns7:href="${this.idPieceJointe}" ns7:title="Evidence"/>
    </rim:RegistryObject>
  </rim:RegistryObjectList>
</query:QueryResponse>
    `;

    const messageBase64 = Buffer.from(message).toString('base64');

    const infosPieceJointe = `
<ns5:PartInfo href="${this.idPieceJointe}">
    <ns5:PartProperties>
        <ns5:Property name="MimeType">${this.typeMimePieceJointe}</ns5:Property>
        <ns5:Property name="CompressionType">application/gzip</ns5:Property>
    </ns5:PartProperties>
</ns5:PartInfo>
    `;

    const pieceJointe = `
<payload payloadId="${this.idPieceJointe}">
  <value>${Buffer.from(this.contenuPieceJointe).toString('base64')}</value>
</payload>
    `;

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
          <eb:Action>ExecuteQueryResponse</eb:Action>
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
          ${infosPieceJointe}
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
      ${pieceJointe}
    </ns4:retrieveMessageResponse>
  </soap:Body>
</soap:Envelope>
    `;
  }
}

module.exports = ConstructeurEnveloppeSOAPAvecPieceJointe;
