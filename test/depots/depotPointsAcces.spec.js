const DepotPointsAcces = require('../../src/depots/depotPointsAcces');
const { ErreurDestinataireInexistant } = require('../../src/erreurs');

describe("Le dépôt des points d'accès", () => {
  const adaptateurDomibus = {};

  beforeEach(() => {
    adaptateurDomibus.trouvePointAcces = () => Promise.resolve();
  });

  it("trouve les informations du point d'accès par son nom", () => {
    adaptateurDomibus.trouvePointAcces = (nom) => {
      const reponse = [{
        name: 'unNom',
        identifiers: [{
          partyId: 'unId',
          partyIdType: {
            name: 'partyTypeUrn',
            value: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator',
          },
        }],
        // … et d'autres valeurs inutilisées
      }];

      try {
        expect(nom).toBe('unNom');
        return Promise.resolve(reponse);
      } catch (e) {
        return Promise.reject(e);
      }
    };

    const depot = new DepotPointsAcces(adaptateurDomibus);
    return expect(depot.trouvePointAcces('unNom')).resolves.toEqual({
      typeIdentifiant: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator',
      id: 'unId',
    });
  });

  it("retourne une `ErreurDestinataireInexistant` si le nom du point d'accès est inconnu", () => {
    expect.assertions(2);
    adaptateurDomibus.trouvePointAcces = () => Promise.resolve([]);

    const depot = new DepotPointsAcces(adaptateurDomibus);
    return depot.trouvePointAcces('unNom')
      .catch((e) => {
        expect(e).toBeInstanceOf(ErreurDestinataireInexistant);
        expect(e.message).toBe("Point d'accès inexistant : unNom");
      });
  });
});
