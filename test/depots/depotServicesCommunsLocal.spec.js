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
});
