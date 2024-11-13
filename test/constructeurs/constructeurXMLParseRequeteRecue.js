const ConstructeurXMLParseMessageRecu = require('./constructeurXMLParseMessageRecu');

class ConstructeurXMLParseRequeteRecue extends ConstructeurXMLParseMessageRecu {
  constructor() {
    super();
    this.codeDemarche = '';
    this.idRequete = '';
  }

  avecCodeDemarche(codeDemarche) {
    this.codeDemarche = codeDemarche;
    return this;
  }

  avecIdRequete(id) {
    this.idRequete = id;
    return this;
  }

  construis() {
    return {
      QueryRequest: {
        '@_id': this.idRequete,
        Slot: [
          {
            '@_name': 'SpecificationIdentifier',
            SlotValue: {
              // …
            },
          },
          {
            '@_name': 'Procedure',
            SlotValue: {
              Value: {
                LocalizedString: {
                  '@_value': this.codeDemarche,
                },
              },
            },
          },
          {
            '@_name': 'EvidenceRequester',
            SlotValue: {
              '@_type': 'rim:CollectionValueType',
              Element: [
                {
                  Agent: {
                    Identifier: { '#text': this.requeteur.id },
                    Name: [
                      { '@_lang': 'FR', '#text': this.requeteur.nom },
                      { '@_lang': 'EN', '#text': 'Some translation' },
                    ],
                    Classification: 'ER',
                  },
                },
                {
                  Agent: {
                    Identifier: { '#text': 'OOTSFRANCE' },
                    Classification: 'IP',
                  },
                },
              ],
            },
          },
        ],
      },
    };
  }
}

module.exports = ConstructeurXMLParseRequeteRecue;
