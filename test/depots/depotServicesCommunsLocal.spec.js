const ConstructeurDepotServicesCommuns = require('../constructeurs/constructeurDepotServicesCommuns');
const { ErreurCodeDemarcheIntrouvable, ErreurTypeJustificatifIntrouvable } = require('../../src/erreurs');
const DepotServicesCommuns = require('../../src/depots/depotServicesCommunsLocal');

describe('Le Dépôt (local, bouchonné) de données des services communs', () => {
  it('trouve un type de justificatif à partir de son identifiant', () => {
    const depot = new ConstructeurDepotServicesCommuns()
      .avecTypeJustificatif({
        id: '12345',
        descriptions: { EN: 'someType' },
        formatDistribution: 'application/pdf',
      })
      .construis();

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

  it('trouve tous les types de justificatifs liés à un code démarche', () => {
    const depot = new ConstructeurDepotServicesCommuns()
      .avecDemarche('00', ['tj1', 'tj2'])
      .construis();

    return depot.trouveTypesJustificatifsPourDemarche('00')
      .then((typesJustificatifs) => {
        expect(typesJustificatifs.length).toBe(2);
        expect(typesJustificatifs[0].descriptions.EN).toBe('tj1');
        expect(typesJustificatifs[1].descriptions.EN).toBe('tj2');
      });
  });

  it('retourne une erreur si code démarche introuvable', () => {
    expect.assertions(2);

    const depot = new ConstructeurDepotServicesCommuns()
      .avecDemarche('00', [])
      .construis();

    return depot.trouveTypesJustificatifsPourDemarche('XX')
      .catch((e) => {
        expect(e).toBeInstanceOf(ErreurCodeDemarcheIntrouvable);
        expect(e.message).toBe('Code démarche "XX" introuvable');
      });
  });
});
