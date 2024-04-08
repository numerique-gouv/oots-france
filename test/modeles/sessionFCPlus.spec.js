const SessionFCPlus = require('../../src/modeles/sessionFCPlus');

describe('Une session FranceConnect+', () => {
  it("connaît son jeton d'accès", () => {
    const session = new SessionFCPlus({ jetonAcces: 'abcdef' });
    expect(session.jetonAcces).toBe('abcdef');
  });

  it("connaît le JWT associé au jeton d'accès", () => {
    const session = new SessionFCPlus({ jwt: 'abcdef' });
    expect(session.jwt).toBe('abcdef');
  });

  it('ajoute les infos utilisateurs chiffrées', () => {
    const session = new SessionFCPlus()
      .avecInfosUtilisateurChiffrees('abcdef');
    expect(session.infosUtilisateurChiffrees).toBe('abcdef');
  });
});
