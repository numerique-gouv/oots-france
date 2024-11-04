const EnteteMessageRecu = require('../../src/domibus/enteteMessageRecu');

describe('Un entête de message Domibus reçu', () => {
  const donnees = {
    Messaging: {
      UserMessage: {
        MessageInfo: {
          MessageId: '00000000-0000-0000-0000-000000000000@domibus.eu',
        },
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

  it("retourne l'identifiant du message en supprimant le suffixe", () => {
    const entete = new EnteteMessageRecu(donnees);
    expect(entete.idMessage()).toBe('00000000-0000-0000-0000-000000000000');
  });

  it("retrouve l'identifiant du payload associé à un type MIME donné", () => {
    const entete = new EnteteMessageRecu(donnees);
    expect(entete.idPayload('application/pdf')).toEqual('cid:22222222-2222-2222-2222-222222222222@pdf.oots.eu');
  });

  it('retourne les différents identifiants de payload par type MIME', () => {
    const entete = new EnteteMessageRecu(donnees);
    expect(entete.payloads()).toEqual({
      'application/x-ebrs+xml': 'cid:11111111-1111-1111-1111-111111111111@regrep.oots.eu',
      'application/pdf': 'cid:22222222-2222-2222-2222-222222222222@pdf.oots.eu',
    });
  });
});
