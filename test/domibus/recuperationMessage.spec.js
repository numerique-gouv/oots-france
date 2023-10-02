const { reponseRecuperationMessage } = require('../../src/domibus/recuperationMessage');

describe('La réponse à une requête Domibus de récupération de message', () => {
  it("connaît l'URL de redirecition spécifiée", () => {
    const message = `<query:QueryResponse
        xmlns:rs="urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0"
        xmlns:query="urn:oasis:names:tc:ebxml-regrep:xsd:query:4.0"
        xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0"
        status="urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure"
        requestId="urn:uuid:11111111-1111-1111-1111-111111111111">

  <rs:Exception xsi:type="rs:AuthorizationExceptionType"
                code="EDM:ERR:0002"
                detail="The server needs authorisation and preview on its side to process the request"
                message="Missing Authorization"
                severity="urn:sr.oots.tech.ec.europa.eu:codes:ErrorSeverity:EDMErrorResponse:PreviewRequired">
    <rim:Slot name="PreviewLocation">
      <rim:SlotValue xsi:type="rim:StringValueType">
        <rim:Value>https://example.com/preview/12345678-1234-1234-1234-1234567890ab</rim:Value>
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

    const reponse = reponseRecuperationMessage(`
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Header>
    <!-- Entêtes SOAP. Inutiles pour ce test -->
  </soap:Header>
  <soap:Body>
    <ns4:retrieveMessageResponse
      xmlns:xmime="http://www.w3.org/2005/05/xmlmime"
      xmlns:ns5="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
      xmlns:ns4="http://eu.domibus.wsplugin/">
      <payload payloadId="cid:11111111-1111-1111-1111-111111111111@oots.eu">
        <value>${messageBase64}</value>
      </payload>
    </ns4:retrieveMessageResponse>
  </soap:Body>
</soap:Envelope>
    `);

    expect(reponse.urlRedirection()).toEqual('https://example.com/preview/12345678-1234-1234-1234-1234567890ab');
  });
});
