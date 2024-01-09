const adaptateurUUID = require('../../src/adaptateurs/adaptateurUUID');
const DepotPointsAcces = require('../../src/depots/depotPointsAcces');
const { ErreurDestinataireInexistant } = require('../../src/erreurs');

class ConstructeurPointAcces {
  constructor() {
    this.nom = adaptateurUUID.genereUUID();
    this.id = this.nom;
    this.typeIdentifiant = 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots-simulator';
  }

  avecId(id) {
    this.id = id;
    return this;
  }

  avecNom(nom) {
    this.nom = nom;
    return this;
  }

  avecTypeIdentifiant(type) {
    this.typeIdentifiant = type;
    return this;
  }

  construis() {
    return {
      name: this.nom,
      identifiers: [{
        partyId: this.id,
        partyIdType: {
          name: 'partyTypeUrn',
          value: this.typeIdentifiant,
        },
      }],
      // … et d'autres valeurs inutilisées
    };
  }
}

describe("Le dépôt des points d'accès", () => {
  const adaptateurDomibus = {};

  beforeEach(() => {
    adaptateurDomibus.trouvePointAcces = () => Promise.resolve();
  });

  it("trouve les informations du point d'accès par son nom", () => {
    adaptateurDomibus.trouvePointAcces = (nom) => {
      const reponse = [
        new ConstructeurPointAcces()
          .avecNom(nom)
          .avecId('unId')
          .avecTypeIdentifiant('urn:unType')
          .construis(),
      ];

      try {
        expect(nom).toBe('unNom');
        return Promise.resolve(reponse);
      } catch (e) {
        return Promise.reject(e);
      }
    };

    const depot = new DepotPointsAcces(adaptateurDomibus);
    return depot.trouvePointAcces('unNom')
      .then((pointAcces) => {
        expect(pointAcces.id).toBe('unId');
        expect(pointAcces.typeId).toBe('urn:unType');
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

  it("retourne une `ErreurDestinataireInexistant` si aucun nom n'est passé en paramètre", () => {
    expect.assertions(2);
    const tousPointsAcces = [new ConstructeurPointAcces().construis()];

    adaptateurDomibus.trouvePointAcces = () => Promise.resolve(tousPointsAcces);

    const depot = new DepotPointsAcces(adaptateurDomibus);
    return depot.trouvePointAcces()
      .catch((e) => {
        expect(e).toBeInstanceOf(ErreurDestinataireInexistant);
        expect(e.message).toBe('Destinataire non renseigné');
      });
  });

  it('retourne une `ErreurDestinataireInexistant` si le nom renseigné est une chaine vide', () => {
    expect.assertions(2);
    const tousPointsAcces = [new ConstructeurPointAcces().construis()];

    adaptateurDomibus.trouvePointAcces = () => Promise.resolve(tousPointsAcces);

    const depot = new DepotPointsAcces(adaptateurDomibus);
    return depot.trouvePointAcces('')
      .catch((e) => {
        expect(e).toBeInstanceOf(ErreurDestinataireInexistant);
        expect(e.message).toBe('Destinataire non renseigné');
      });
  });
});
