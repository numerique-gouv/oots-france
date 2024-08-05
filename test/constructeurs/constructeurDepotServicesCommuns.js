const DepotServicesCommuns = require('../../src/depots/depotServicesCommunsLocal');

class ConstructeurDepotServicesCommuns {
  constructor() {
    this.donnees = {};
    this.compteur = 0;
  }

  avecTypeJustificatif(donnees) {
    const donneesParDefaut = {
      id: (this.compteur += 1),
      descriptions: { EN: '' },
      formatDistribution: 'application/xml',
    };

    this.donnees.typesJustificatif ||= [];
    this.donnees.typesJustificatif.push(Object.assign(donneesParDefaut, donnees));
    return this;
  }

  avecDemarche(code, descriptionsTypeJustificatif) {
    const donneesDemarche = { code, idsTypeJustificatif: [] };
    descriptionsTypeJustificatif.forEach((description) => {
      const donneesTypeJustificatif = {};
      this.compteur += 1;
      donneesTypeJustificatif.id = this.compteur;
      donneesTypeJustificatif.descriptions = { EN: description };
      this.avecTypeJustificatif(donneesTypeJustificatif);
      donneesDemarche.idsTypeJustificatif.push(donneesTypeJustificatif.id);
    });
    this.donnees.demarches ||= [];
    this.donnees.demarches.push(donneesDemarche);
    return this;
  }

  construis() {
    return new DepotServicesCommuns(this.donnees);
  }
}

module.exports = ConstructeurDepotServicesCommuns;
