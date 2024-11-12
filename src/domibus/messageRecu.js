const { ErreurAttributInconnu } = require('../erreurs');

class MessageRecu {
  constructor(xmlParse) {
    this.xmlParse = xmlParse;
  }

  idRequete() {
    throw new ErreurAttributInconnu(`Pas d'identifiant de requête dans un message Domibus de type ${this.constructor.name}`);
  }

  static idRequeteur = (xmlRequeteur) => xmlRequeteur.Identifier['#text']?.toString();

  static nomRequeteur = (xmlRequeteur) => []
    .concat(xmlRequeteur.Name ?? [])
    ?.[0]
    ?.['#text'];
}

module.exports = MessageRecu;
