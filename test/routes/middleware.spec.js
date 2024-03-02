const { ErreurJetonInvalide } = require('../../src/erreurs');
const Middleware = require('../../src/routes/middleware');

describe('Le middleware OOTS-France', () => {
  const adaptateurChiffrement = {};
  const adaptateurEnvironnement = {};
  const config = { adaptateurChiffrement, adaptateurEnvironnement };
  let requete;

  beforeEach(() => {
    adaptateurEnvironnement.secretJetonSession = () => '';
    adaptateurChiffrement.verifieJeton = () => Promise.resolve();

    requete = { session: { jeton: '' } };
  });

  it('vérifie le jeton stocké en session', (suite) => {
    requete.session.jeton = 'jeton';
    adaptateurEnvironnement.secretJetonSession = () => 'secret';
    adaptateurChiffrement.verifieJeton = (jeton, secret) => {
      try {
        expect(jeton).toBe('jeton');
        expect(secret).toBe('secret');

        return Promise.resolve();
      } catch (e) { return Promise.reject(e); }
    };

    const middleware = new Middleware(config);

    middleware.renseigneUtilisateurCourant(requete, null, suite)
      .catch(suite);
  });

  it("renseigne les infos de l'utilisateur courant dans la requête", (suite) => {
    adaptateurChiffrement.verifieJeton = () => Promise.resolve({ infos: 'des infos' });

    const middleware = new Middleware(config);
    expect(requete.utilisateurCourant).toBeUndefined();

    middleware.renseigneUtilisateurCourant(requete, null, () => {
      try {
        expect(requete.utilisateurCourant).toEqual({ infos: 'des infos' });
        suite();
      } catch (e) { suite(e); }
    })
      .catch(suite);
  });

  it("supprime les infos de l'utilisateur courant si le jeton est invalide", (suite) => {
    adaptateurChiffrement.verifieJeton = () => Promise.reject(new ErreurJetonInvalide('oups'));

    const middleware = new Middleware(config);
    middleware.renseigneUtilisateurCourant(requete, null, () => {
      expect(requete.utilisateurCourant).toBeUndefined();
      suite();
    })
      .catch(suite);
  });
});
