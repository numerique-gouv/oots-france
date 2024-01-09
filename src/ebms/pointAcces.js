class PointAcces {
  static expediteur() {
    const id = process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS;
    const typeId = process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS;

    return new PointAcces(id, typeId);
  }

  constructor(id, typeId) {
    this.id = id;
    this.typeId = typeId;
  }

  enXML() {
    return `
<eb:PartyId type="${this.typeId}">${this.id}</eb:PartyId>
<eb:Role>http://sdg.europa.eu/edelivery/gateway</eb:Role>
    `;
  }
}

module.exports = PointAcces;
