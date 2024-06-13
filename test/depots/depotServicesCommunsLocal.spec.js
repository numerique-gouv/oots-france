const { ErreurTypeJustificatifIntrouvable } = require('../../src/erreurs');
const DepotServicesCommuns = require('../../src/depots/depotServicesCommunsLocal');

describe('Le Dépôt (local, bouchonné) de données des services communs', () => {
  it('trouve un type de justificatif à partir de son identifiant', () => {
    const depot = new DepotServicesCommuns({
      typesJustificatif: [{
        id: '12345',
        descriptions: { EN: 'someType' },
        formatDistribution: 'application/pdf',
      }],
    });

    return depot.trouveTypeJustificatif('12345')
      .then((typeJustificatif) => {
        expect(typeJustificatif.id).toBe('12345');
        expect(typeJustificatif.descriptions).toEqual({ EN: 'someType' });
        expect(typeJustificatif.formatDistribution).toBe('application/pdf');
      });
  });

  it('retourne une erreur si type justificatif introuvable', () => {
    expect.assertions(2);

    const depot = new DepotServicesCommuns({});

    return depot.trouveTypeJustificatif('12345')
      .catch((e) => {
        expect(e).toBeInstanceOf(ErreurTypeJustificatifIntrouvable);
        expect(e.message).toBe('Type justificatif avec identifiant "12345" introuvable');
      });
  });
});
