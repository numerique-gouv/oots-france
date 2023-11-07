const ReponseErreur = require('../../src/domibus/reponseErreur');
const { ErreurReponseRequete } = require('../../src/erreurs');

describe("Une réponse Domibus reçue en erreur (différente d'autorisation requise)", () => {
  it('lance une erreur comme suite de conversation', (suite) => {
    const xmlParse = { QueryResponse: { Exception: { '@_message': 'oups' } } };
    const reponse = new ReponseErreur(xmlParse);

    try {
      reponse.suiteConversation();
      suite('La suite de conversation aurait dû lever une ErreurReponseRequete');
    } catch (e) {
      expect(e).toBeInstanceOf(ErreurReponseRequete);
      expect(e.message).toEqual('oups');
      suite();
    }
  });
});
