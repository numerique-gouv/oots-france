class ConstructeurXMLParseMessageRecu {
  constructor() {
    this.requeteur = { id: '', nom: '' };
  }

  avecRequeteur({ id, nom }) {
    Object.assign(this.requeteur, { id, nom });
    return this;
  }
}

module.exports = ConstructeurXMLParseMessageRecu;
