class MessageRecu {
  constructor(xmlParse) {
    this.xmlParse = xmlParse;
  }

  static idRequeteur = (xmlRequeteur) => xmlRequeteur.Identifier['#text']?.toString();

  static nomRequeteur = (xmlRequeteur) => []
    .concat(xmlRequeteur.Name ?? [])
    ?.[0]
    ?.['#text'];
}

module.exports = MessageRecu;
