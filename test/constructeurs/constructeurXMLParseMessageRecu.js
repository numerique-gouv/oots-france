class ConstructeurXMLParseMessageRecu {
  constructor() {
    this.requeteur = { id: 'BR_SI_01', nom: 'Un requêteur slovène' }
  }

  avecRequeteur({ id, nom }) {
    Object.assign(this.requeteur, { id, nom })
    return this
  }
}

module.exports = ConstructeurXMLParseMessageRecu
