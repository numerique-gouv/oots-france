const TypeJustificatif = require('../ebms/typeJustificatif');

const DONNEES_DEPOT = {
  typesJustificatif: [{
    id: '12345',
    descriptions: { EN: 'someDummyType' },
    formatDistribution: 'application/pdf',
  }],
};

class DepotServicesCommunsLocal {
  constructor(donnees = DONNEES_DEPOT) {
    this.donnees = donnees;
  }

  trouveTypeJustificatif(id) {
    const donneesTypeJustificatif = this.donnees.typesJustificatif.find((tj) => tj.id === id);
    const typeJustificatif = new TypeJustificatif(donneesTypeJustificatif);
    return Promise.resolve(typeJustificatif);
  }
}

module.exports = DepotServicesCommunsLocal;
