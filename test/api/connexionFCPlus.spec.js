const connexionFCPlus = require('../../src/api/connexionFCPlus');

describe('Le requêteur de connexion FC+', () => {
  const adaptateurChiffrement = {};
  const fabriqueSessionFCPlus = {};
  const config = { adaptateurChiffrement, fabriqueSessionFCPlus };
  const requete = {};
  const reponse = {};

  beforeEach(() => {
    adaptateurChiffrement.genereJeton = () => Promise.resolve();
    fabriqueSessionFCPlus.nouvelleSession = () => Promise.resolve({
      enJSON: () => Promise.resolve({}),
    });
    requete.session = {};
    reponse.json = () => Promise.resolve();
    reponse.redirect = () => Promise.resolve();
    reponse.status = () => reponse;
  });

  it('conserve les infos utilisateurs dans un cookie de session', () => {
    adaptateurChiffrement.genereJeton = () => Promise.resolve('XXX');

    expect(requete.session.jeton).toBeUndefined();
    return connexionFCPlus(config, 'unCode', requete, reponse)
      .then(() => expect(requete.session.jeton).toBe('XXX'));
  });

  it('supprime le jeton déjà en session sur erreur récupération infos', () => {
    fabriqueSessionFCPlus.nouvelleSession = () => Promise.resolve({
      enJSON: () => Promise.reject(new Error('oups')),
    });
    adaptateurChiffrement.genereJeton = () => Promise.resolve('abcdef');

    requete.session.jeton = 'unJeton';
    return connexionFCPlus(config, 'unCode', requete, reponse)
      .then(() => expect(requete.session.jeton).toBeUndefined());
  });
});
