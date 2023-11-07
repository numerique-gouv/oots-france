const ReponseErreurAutorisationRequise = require('../../src/domibus/reponseErreurAutorisationRequise');

describe('Une réponse Domibus reçue avec erreur autorisation requise', () => {
  it("renvoie comme suite de conversation l'URL de redirection", () => {
    const xmlParse = {
      QueryResponse: {
        Exception: {
          Slot: [
            {
              '@_name': 'PreviewLocation',
              SlotValue: { Value: 'https://example.com' },
            },
          ],
        },
      },
    };

    const reponse = new ReponseErreurAutorisationRequise(xmlParse);
    expect(reponse.suiteConversation()).toEqual('https://example.com');
  });
});
