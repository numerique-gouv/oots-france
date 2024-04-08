const { ErreurEchecAuthentification } = require('../../src/erreurs');
const SessionFCPlus = require('../../src/modeles/sessionFCPlus');

describe('Une session FranceConnect+', () => {
  const adaptateurChiffrement = {};
  const adaptateurFranceConnectPlus = {};
  const config = { adaptateurChiffrement, adaptateurFranceConnectPlus };

  beforeEach(() => {
    adaptateurChiffrement.dechiffreJWE = () => Promise.resolve('');
    adaptateurChiffrement.verifieSignatureJWTDepuisJWKS = () => Promise.resolve({});
    adaptateurFranceConnectPlus.recupereDonneesJetonAcces = () => Promise.resolve({});
    adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees = () => Promise.resolve('');
    adaptateurFranceConnectPlus.recupereURLClefsPubliques = () => Promise.resolve('');
  });

  describe('sur demande peuplement donnees jeton accès', () => {
    it("conserve le jeton d'accès", () => {
      adaptateurFranceConnectPlus.recupereDonneesJetonAcces = (code) => {
        try {
          expect(code).toBe('unCode');
          return Promise.resolve({ access_token: 'abcdef' });
        } catch (e) {
          return Promise.reject(e);
        }
      };

      const session = new SessionFCPlus(config, 'unCode');
      return session.peupleDonneesJetonAcces()
        .then(() => {
          expect(session.jetonAcces).toBe('abcdef');
        });
    });

    it('conserve le JWT associé', () => {
      adaptateurFranceConnectPlus.recupereDonneesJetonAcces = () => Promise.resolve({ id_token: '123' });
      adaptateurChiffrement.dechiffreJWE = (jwe) => {
        try {
          expect(jwe).toBe('123');
          return Promise.resolve('999');
        } catch (e) {
          return Promise.reject(e);
        }
      };

      const session = new SessionFCPlus(config, 'unCode');
      return session.peupleDonneesJetonAcces()
        .then(() => {
          expect(session.jwt).toBe('999');
        });
    });

    it("conserve l'URL des clefs publiques FC+", () => {
      adaptateurFranceConnectPlus.recupereURLClefsPubliques = () => Promise.resolve('http://example.com');

      const session = new SessionFCPlus(config, 'unCode');
      return session.peupleDonneesJetonAcces()
        .then(() => {
          expect(session.urlClefsPubliques).toBe('http://example.com');
        });
    });
  });

  describe('sur demande infos utilisateur déchiffrées', () => {
    it('récupère les infos', () => {
      adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees = (jetonAcces) => {
        try {
          expect(jetonAcces).toBe('abcdef');
          return Promise.resolve('123');
        } catch (e) {
          return Promise.reject(e);
        }
      };

      adaptateurChiffrement.dechiffreJWE = (jwe) => {
        try {
          expect(jwe).toBe('123');
          return Promise.resolve('999');
        } catch (e) {
          return Promise.reject(e);
        }
      };

      const session = new SessionFCPlus(config, 'unCode');
      session.conserveJetonAcces('abcdef');

      return session.infosUtilisateurDechiffrees()
        .then((jwt) => {
          expect(jwt).toBe('999');
        });
    });
  });

  describe('sur demande description données', () => {
    it('vérifie la signature du JWT des infos utilisateur', () => {
      let signatureVerifiee = false;
      adaptateurChiffrement.verifieSignatureJWTDepuisJWKS = () => {
        signatureVerifiee = true;
        return Promise.resolve({});
      };

      const session = new SessionFCPlus(config, 'unCode');
      return session.enJSON()
        .then(() => expect(signatureVerifiee).toBe(true));
    });

    it('ajoute le JWT de session aux infos utilisateur', () => {
      adaptateurFranceConnectPlus.recupereURLClefsPubliques = () => Promise.resolve('http://example.com');
      adaptateurFranceConnectPlus.recupereDonneesJetonAcces = () => Promise.resolve({ id_token: '999' });
      adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees = () => Promise.resolve('aaa');
      adaptateurChiffrement.dechiffreJWE = (jwe) => Promise.resolve(jwe);
      adaptateurChiffrement.verifieSignatureJWTDepuisJWKS = (jwt, url) => {
        try {
          expect(jwt).toBe('aaa');
          expect(url).toBe('http://example.com');
          return Promise.resolve({ uneClef: 'uneValeur' });
        } catch (e) {
          return Promise.reject(e);
        }
      };

      const session = new SessionFCPlus(config, 'unCode');
      session.jwt = '999';

      return session.enJSON()
        .then((json) => expect(json).toEqual({
          uneClef: 'uneValeur',
          jwtSessionFCPlus: '999',
        }));
    });

    it('lève une `ErreurEchecAuthentification` si une erreur est rencontrée', () => {
      expect.assertions(2);

      adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees = () => Promise.reject(new Error('oups'));

      const session = new SessionFCPlus(config, 'unCode');

      return session.enJSON()
        .catch((e) => {
          expect(e).toBeInstanceOf(ErreurEchecAuthentification);
          expect(e.message).toBe('oups');
        });
    });
  });
});
