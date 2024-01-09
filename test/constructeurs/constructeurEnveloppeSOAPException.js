const PointAcces = require('../../src/ebms/pointAcces');

class ConstructeurEnveloppeSOAPException {
  static erreurAutorisationRequise() {
    return new ConstructeurEnveloppeSOAPException()
      .avecErreur({
        type: 'rs:AuthorizationExceptionType',
        code: 'EDM:ERR:0002',
        detail: 'The server needs authorisation and preview on its side to process the request',
        message: 'Missing Authorization',
        severite: 'urn:sr.oots.tech.ec.europa.eu:codes:ErrorSeverity:EDMErrorResponse:PreviewRequired',
      });
  }

  constructor() {
    this.idPayload = 'cid:99999999-9999-9999-9999-999999999999@oots.eu';
    this.expediteur = PointAcces.expediteur();
  }

  avecErreur({
    type,
    code,
    detail,
    message,
    severite,
  }) {
    this.typeErreur = type;
    this.codeErreur = code;
    this.detailErreur = detail;
    this.messageErreur = message;
    this.severiteErreur = severite;

    return this;
  }

  avecExpediteur(expediteur) {
    this.expediteur = expediteur;
    return this;
  }

  avecIdConversation(id) {
    this.idConversation = id;
    return this;
  }

  avecIdMessage(id) {
    this.idMessage = id;
    return this;
  }

  avecIdPayload(id) {
    this.idPayload = id;
    return this;
  }

  avecURLRedirection(url) {
    this.urlRedirection = url;
    return this;
  }

  construis() {
    const message = `<query:QueryResponse
        xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
        xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
        xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
        status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure"
        requestId="urn:uuid:11111111-1111-1111-1111-111111111111">

  <rs:Exception xsi:type="${this.typeErreur}"
                code="${this.codeErreur}"
                detail="${this.detailErreur}"
                message="${this.messageErreur}"
                severity="${this.severiteErreur}">
    <rim:Slot name="PreviewLocation">
      <rim:SlotValue xsi:type="rim:StringValueType">
        <rim:Value>${this.urlRedirection}</rim:Value>
      </rim:SlotValue>
    </rim:Slot>
    <rim:Slot name="Timestamp">
      <rim:SlotValue xsi:type="rim:DateTimeValueType">
        <rim:Value>2023-10-02T11:30:00.000+02:00</rim:Value>
      </rim:SlotValue>
    </rim:Slot>
  </rs:Exception>
</query:QueryResponse>`;

    const messageBase64 = Buffer.from(message).toString('base64');

    return `
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Header>
    <ns5:Messaging>
      <ns5:UserMessage>
        <ns5:MessageInfo>
            <ns5:Timestamp>2023-09-24T09:07:45.000Z</ns5:Timestamp>
            <ns5:MessageId>${this.idMessage}</ns5:MessageId>
        </ns5:MessageInfo>
        <ns5:PartyInfo>
            <ns5:From>
                ${this.expediteur.enXML()}
            </ns5:From>
            <ns5:To>
                <ns5:PartyId type="urn:oasis:names:tc:ebcore:partyid-type:unregistered">GovernmentNLGateway01</ns5:PartyId>
                <ns5:Role>http://sdg.europa.eu/edelivery/gateway</ns5:Role>
            </ns5:To>
        </ns5:PartyInfo>
        <ns5:CollaborationInfo>
            <ns5:Service type="urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0">QueryManager</ns5:Service>
            <ns5:Action>ExceptionResponse</ns5:Action>
            <ns5:ConversationId>${this.idConversation}</ns5:ConversationId>
        </ns5:CollaborationInfo>
        <ns5:MessageProperties>
            <ns5:Property name="originalSender" type="urn:cef.eu:names:identifier:EAS:0204">02-SchoolAuthority-34</ns5:Property>
            <ns5:Property name="finalRecipient" type="urn:cef.eu:names:identifier:EAS:0190">NL222332239</ns5:Property>
        </ns5:MessageProperties>
        <ns5:PayloadInfo>
            <ns5:PartInfo href="${this.idPayload}">
                <ns5:PartProperties>
                    <ns5:Property name="MimeType">application/x-ebrs+xml</ns5:Property>
                    <ns5:Property name="CompressionType">application/gzip</ns5:Property>
                </ns5:PartProperties>
            </ns5:PartInfo>
        </ns5:PayloadInfo>
      </ns5:UserMessage>
    </ns5:Messaging>
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

module.exports = ConstructeurEnveloppeSOAPException;
