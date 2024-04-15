const { ErreurEchecAuthentification } = require('../../src/erreurs');
const SessionFCPlus = require('../../src/modeles/sessionFCPlus');

describe('Une session FranceConnect+', () => {
  const adaptateurChiffrement = {};
  const adaptateurFranceConnectPlus = {};
  const config = { adaptateurChiffrement, adaptateurFranceConnectPlus };

  beforeEach(() => {
    adaptateurChiffrement.dechiffreJWE = () => Promise.resolve('');
    adaptateurChiffrement.verifieSignatureJWTDepuisJWKS = () => Promise.resolve({});
    adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees = () => Promise.resolve('');
  });

  const nouvelleSession = ({
    jetonAcces = 'unJetonAcces',
    jwt = 'unJWT',
    urlClefsPubliques = 'uneURL',
  } = {}) => {
    const session = new SessionFCPlus(config);
    Object.assign(session, { jetonAcces, jwt, urlClefsPubliques });

    return session;
  };

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
      session.jetonAcces = 'abcdef';

      return session.infosUtilisateurDechiffrees()
        .then((jwt) => {
          expect(jwt).toBe('999');
        });
    });

    it("lève une erreur si le jeton d'accès n'est pas défini", () => {
      expect.assertions(2);

      const session = nouvelleSession({ jetonAcces: '' });
      expect(session.jetonAcces).toBeFalsy();

      return session.infosUtilisateurDechiffrees()
        .catch((e) => expect(e.message).toBe('Jeton accès non défini. La session a-t-elle bien été instanciée depuis la fabrique ?'));
    });
  });

  describe('sur demande description données', () => {
    it('vérifie la signature du JWT des infos utilisateur', () => {
      let signatureVerifiee = false;
      adaptateurChiffrement.verifieSignatureJWTDepuisJWKS = () => {
        signatureVerifiee = true;
        return Promise.resolve({});
      };

      const session = nouvelleSession();
      return session.enJSON()
        .then(() => expect(signatureVerifiee).toBe(true));
    });

    it('ajoute le JWT de session aux infos utilisateur', () => {
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

      const session = nouvelleSession({ jwt: '999', urlClefsPubliques: 'http://example.com' });

      return session.enJSON()
        .then((json) => expect(json).toEqual({
          uneClef: 'uneValeur',
          jwtSessionFCPlus: '999',
        }));
    });

    it('lève une `ErreurEchecAuthentification` si une erreur est rencontrée', () => {
      expect.assertions(2);

      adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees = () => Promise.reject(new Error('oups'));

      const session = nouvelleSession();

      return session.enJSON()
        .catch((e) => {
          expect(e).toBeInstanceOf(ErreurEchecAuthentification);
          expect(e.message).toBe('oups');
        });
    });

    it("lève une erreur si le JWT n'est pas défini", () => {
      expect.assertions(2);

      const session = nouvelleSession({ jwt: '' });
      expect(session.jwt).toBeFalsy();

      return session.enJSON()
        .catch((e) => expect(e.message).toBe('JWT non défini. La session a-t-elle bien été instanciée depuis la fabrique ?'));
    });

    it("lève une erreur si l'URL des clefs publiques n'est pas définie", () => {
      expect.assertions(2);

      const session = nouvelleSession({ urlClefsPubliques: '' });
      expect(session.urlClefsPubliques).toBeFalsy();

      return session.enJSON()
        .catch((e) => expect(e.message).toBe('URL clefs publiques non définie. La session a-t-elle bien été instanciée depuis la fabrique ?'));
    });
  });
});
