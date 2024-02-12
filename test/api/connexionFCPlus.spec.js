const connexionFCPlus = require('../../src/api/connexionFCPlus');

describe('Le requêteur de connexion FC+', () => {
  const adaptateurFranceConnectPlus = {};
  const config = { adaptateurFranceConnectPlus };
  const requete = {};
  const reponse = {};

  beforeEach(() => {
    adaptateurFranceConnectPlus.recupereInfosUtilisateur = () => Promise.resolve({});
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
});
