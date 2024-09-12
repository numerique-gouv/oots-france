const { ErreurRequeteurInexistant } = require('../../src/erreurs');
const DepotRequeteurs = require('../../src/depots/depotRequeteurs');

describe('Le dépôt des requêteurs', () => {
  it('sait retrouver un requêteur en fonction de son identifiant', () => {
    const depot = new DepotRequeteurs({
      123: { nom: 'un requêteur', url: 'http://example.com' },
    });

    return depot.trouveRequeteur('123')
      .then((requeteur) => {
        expect(requeteur.id).toBe('123');
        expect(requeteur.nom).toBe('un requêteur');
        expect(requeteur.url).toBe('http://example.com');
      });
  });

  it("retourne une exception si le requêteur n'existe pas", () => {
    expect.assertions(2);
    const depot = new DepotRequeteurs({});

    return depot.trouveRequeteur('123')
      .catch((e) => {
        expect(e).toBeInstanceOf(ErreurRequeteurInexistant);
        expect(e.message).toBe('Le requêteur avec comme identifiant "123" est inexistant');
      });
  });
});
