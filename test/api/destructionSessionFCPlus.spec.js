const destructionSessionFCPlus = require('../../src/api/destructionSessionFCPlus');

describe('Le requêteur de destruction de session FC+', () => {
  const adaptateurChiffrement = {};
  const adaptateurEnvironnement = {};
  const adaptateurFranceConnectPlus = {};
  const config = { adaptateurChiffrement, adaptateurEnvironnement, adaptateurFranceConnectPlus };
  const reponse = {};

  let requete = {};

  beforeEach(() => {
    adaptateurChiffrement.cleHachage = () => '';
    adaptateurEnvironnement.urlRedirectionDeconnexion = () => '';
    adaptateurFranceConnectPlus.urlDestructionSession = () => Promise.resolve('');
    requete = {};
    reponse.end = () => Promise.resolve();
    reponse.redirect = () => Promise.resolve();
  });

  describe('quand le JWT de session FC+ existe', () => {
    beforeEach(() => {
      requete.utilisateurCourant = { jwtSessionFCPlus: '' };
    });

    it('redirige vers serveur FC+', () => {
      expect.assertions(1);
      adaptateurFranceConnectPlus.urlDestructionSession = () => Promise.resolve('http://example.com');

      reponse.redirect = (url) => {
        try {
          expect(url).toMatch(/^http:\/\/example\.com\?/);
          return Promise.resolve();
        } catch (e) {
          return Promise.reject(e);
        }
      };

      destructionSessionFCPlus(config, requete, reponse);
    });

    it('récupère le JWT de session FC+ stocké dans la session locale', () => {
      expect.assertions(1);

      requete.utilisateurCourant = { jwtSessionFCPlus: 'abcdef' };
      reponse.redirect = (url) => {
        try {
          expect(url).toContain('id_token_hint=abcdef');
          return Promise.resolve();
        } catch (e) {
          return Promise.reject(e);
        }
      };

      destructionSessionFCPlus(config, requete, reponse);
    });

    it('ajoute un état en paramètre de la requête', () => {
      expect.assertions(1);
      adaptateurChiffrement.cleHachage = () => '12345';

      reponse.redirect = (url) => {
        try {
          expect(url).toContain('state=12345');
          return Promise.resolve();
        } catch (e) {
          return Promise.reject(e);
        }
      };

      destructionSessionFCPlus(config, requete, reponse);
    });

    it("ajoute l'URL de redirection post-logout en paramètre de la requête", () => {
      expect.assertions(1);
      adaptateurEnvironnement.urlRedirectionDeconnexion = () => 'http://example.com';

      reponse.redirect = (url) => {
        try {
          expect(url).toContain('post_logout_redirect_uri=http://example.com');
          return Promise.resolve();
        } catch (e) {
          return Promise.reject(e);
        }
      };

      destructionSessionFCPlus(config, requete, reponse);
    });
  });

  describe('Quand le JWT de session est inexistant', () => {
    it('redirige vers `/auth/fcplus/deconnexion`', () => {
      expect.assertions(2);
      expect(requete.utilisateurCourant).toBeUndefined();

      reponse.redirect = (url) => {
        try {
          expect(url).toBe('/auth/fcplus/deconnexion');
          return Promise.resolve();
        } catch (e) {
          return Promise.reject(e);
        }
      };

      destructionSessionFCPlus(config, requete, reponse);
    });
  });
});
