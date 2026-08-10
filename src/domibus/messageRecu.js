const { ErreurAttributInconnu } = require('../erreurs')

class MessageRecu {
  constructor(xmlParse) {
    this.xmlParse = xmlParse
  }

  idRequete() {
    throw new ErreurAttributInconnu(`Pas d'identifiant de requête dans un message Domibus de type ${this.constructor.name}`)
  }

  static idRequeteur = xmlRequeteur => xmlRequeteur.Identifier['#text']?.toString()

  static typeIdRequeteur = xmlRequeteur => xmlRequeteur.Identifier['@_schemeID']

  // fast-xml-parser rend un objet quand le nom est seul, un tableau au-delà.
  static premierNom = xmlRequeteur => [].concat(xmlRequeteur.Name ?? [])[0]

  static nomRequeteur = xmlRequeteur => MessageRecu.premierNom(xmlRequeteur)?.['#text']

  // La langue déclarée sur le nom : la réémettre telle quelle évite d'annoncer
  // en français le nom d'une organisation qui ne l'est pas.
  static langueRequeteur = xmlRequeteur => MessageRecu.premierNom(xmlRequeteur)?.['@_lang']
}

module.exports = MessageRecu
