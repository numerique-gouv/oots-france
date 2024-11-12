const { ErreurAttributInconnu } = require('../../src/erreurs');
const MessageRecu = require('../../src/domibus/messageRecu');

describe('Un message reçu de domibus', () => {
  it("n'a pas d'identifiant de requête par défaut", () => {
    const messageDomibus = new MessageRecu();
    try {
      messageDomibus.idRequete();
      throw new Error("L'appel à `idRequete` aurait dû lever une exception");
    } catch (e) {
      expect(e).toBeInstanceOf(ErreurAttributInconnu);
      expect(e.message).toBe("Pas d'identifiant de requête dans un message Domibus de type MessageRecu");
    }
  });
});
