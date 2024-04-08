const connexionFCPlus = require('../../src/api/connexionFCPlus');

describe('Le requêteur de connexion FC+', () => {
  const adaptateurChiffrement = {};
  const adaptateurFranceConnectPlus = {};
  const config = { adaptateurChiffrement, adaptateurFranceConnectPlus };
  const requete = {};
  const reponse = {};

  beforeEach(() => {
    adaptateurChiffrement.dechiffreJWE = () => Promise.resolve();
    adaptateurChiffrement.genereJeton = () => Promise.resolve();
    adaptateurChiffrement.verifieSignatureJWTDepuisJWKS = () => Promise.resolve({});
    adaptateurFranceConnectPlus.recupereDonneesJetonAcces = () => Promise.resolve({});
    adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees = () => Promise.resolve();
    adaptateurFranceConnectPlus.recupereURLClefsPubliques = () => Promise.resolve();
    requete.session = {};
    reponse.json = () => Promise.resolve();
    reponse.status = () => reponse;
  });

  it('retourne les infos de la session FC+ en JSON', () => {
    expect.assertions(1);

    adaptateurChiffrement.dechiffreJWE = () => Promise.resolve('abcdef');
    adaptateurChiffrement.verifieSignatureJWTDepuisJWKS = () => Promise.resolve({ infos: 'des infos' });

    reponse.json = (donnees) => {
      expect(donnees).toEqual({ infos: 'des infos', jwtSessionFCPlus: 'abcdef' });
      return Promise.resolve();
    };

    return connexionFCPlus(config, 'unCode', requete, reponse);
  });

  it('conserve les infos utilisateurs dans un cookie de session', () => {
    adaptateurChiffrement.genereJeton = () => Promise.resolve('XXX');

    expect(requete.session.jeton).toBeUndefined();
    return connexionFCPlus(config, 'unCode', requete, reponse)
      .then(() => expect(requete.session.jeton).toBe('XXX'));
  });

  it('supprime le jeton déjà en session sur erreur récupération infos', () => {
    adaptateurChiffrement.genereJeton = () => Promise.resolve('abcdef');
    adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees = () => Promise.reject(new Error('oups'));

    requete.session.jeton = 'unJeton';
    return connexionFCPlus(config, 'unCode', requete, reponse)
      .then(() => expect(requete.session.jeton).toBeUndefined());
  });
});
