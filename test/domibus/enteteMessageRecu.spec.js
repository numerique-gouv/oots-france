const EnteteMessageRecu = require('../../src/domibus/enteteMessageRecu');

describe('Un entête de message Domibus reçu', () => {
  it("retrouve l'identifiant du payload associé au type MIME `application/x-ebrs+xml`", () => {
    const donnees = {
      Messaging: {
        UserMessage: {
          PayloadInfo: {
            PartInfo: [{
              '@_href': 'cid:11111111-1111-1111-1111-111111111111@regrep.oots.eu',
              PartProperties: { Property: { '@_name': 'MimeType', '#text': 'application/x-ebrs+xml' } },
            }, {
              '@_href': 'cid:22222222-2222-2222-2222-222222222222@pdf.oots.eu',
              PartProperties: { Property: { '@_name': 'MimeType', '#text': 'application/pdf' } },
            }],
          },
        },
      },
    };

    const entete = new EnteteMessageRecu(donnees);

    expect(entete.idPayload()).toEqual('cid:11111111-1111-1111-1111-111111111111@regrep.oots.eu');
  });
});
