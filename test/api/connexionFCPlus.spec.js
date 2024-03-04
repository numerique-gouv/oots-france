const connexionFCPlus = require('../../src/api/connexionFCPlus');
const { ErreurEchecAuthentification } = require('../../src/erreurs');

describe('Le requêteur de connexion FC+', () => {
  const adaptateurChiffrement = {};
  const adaptateurFranceConnectPlus = {};
  const config = { adaptateurChiffrement, adaptateurFranceConnectPlus };
  const requete = {};
  const reponse = {};

  beforeEach(() => {
    adaptateurChiffrement.genereJeton = () => Promise.resolve();
    adaptateurFranceConnectPlus.recupereInfosUtilisateur = () => Promise.resolve({});
    requete.session = {};
    reponse.json = () => Promise.resolve();
    reponse.status = () => reponse;
  });

  it('interroge le serveur FC+ pour obtenir les infos utilisateurs', () => {
    expect.assertions(1);

    adaptateurFranceConnectPlus.recupereInfosUtilisateur = (code) => {
      expect(code).toBe('unCode');
      return Promise.resolve({});
    };

    return connexionFCPlus(config, 'unCode', requete, reponse);
  });

  it('retourne les infos utilisateurs obtenues en JSON', () => {
    expect.assertions(1);

    adaptateurFranceConnectPlus.recupereInfosUtilisateur = () => Promise.resolve({ infos: 'des infos' });

    reponse.json = (donnees) => {
      expect(donnees).toEqual({ infos: 'des infos' });
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
    adaptateurFranceConnectPlus.recupereInfosUtilisateur = () => Promise.reject(new ErreurEchecAuthentification('oups'));

    requete.session.jeton = 'unJeton';
    return connexionFCPlus(config, 'unCode', requete, reponse)
      .then(() => expect(requete.session.jeton).toBeUndefined());
  });
});
