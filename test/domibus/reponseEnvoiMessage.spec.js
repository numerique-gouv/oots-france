const ReponseEnvoiMessage = require('../../src/domibus/reponseEnvoiMessage');

describe("La réponse d'un envoi de message Domibus", () => {
  it("connaît l'identifiant du message envoyé", () => {
    const donnees = `
<soap:Envelope
  xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Body>
    <ns4:submitResponse
      xmlns:xmime="http://www.w3.org/2005/05/xmlmime"
      xmlns:ns5="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/"
      xmlns:ns4="http://eu.domibus.wsplugin/">
      <messageID>12345678-1234-1234-1234-1234567890ab@oots.eu</messageID>
    </ns4:submitResponse>
  </soap:Body>
</soap:Envelope>
  `;

    const reponse = new ReponseEnvoiMessage(donnees);

    expect(reponse.idMessage()).toEqual('12345678-1234-1234-1234-1234567890ab@oots.eu');
  });
});
