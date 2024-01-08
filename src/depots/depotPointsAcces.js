const { ErreurDestinataireInexistant } = require('../erreurs');

class DepotPointsAcces {
  constructor(adaptateurDomibus) {
    this.adaptateurDomibus = adaptateurDomibus;
  }

  trouvePointAcces(nom) {
    if (typeof nom === 'undefined' || nom === '') {
      return Promise.reject(new ErreurDestinataireInexistant('Destinataire non renseigné'));
    }

    return this.adaptateurDomibus.trouvePointAcces(nom)
      .then((pointsAcces) => {
        if (pointsAcces.length === 0) {
          throw new ErreurDestinataireInexistant(`Point d'accès inexistant : ${nom}`);
        }

        const infosIdentifiant = pointsAcces[0].identifiers[0];
        return {
          typeIdentifiant: infosIdentifiant.partyIdType.value,
          id: infosIdentifiant.partyId,
        };
      });
  }
}

module.exports = DepotPointsAcces;
