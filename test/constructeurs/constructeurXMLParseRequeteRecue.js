const ConstructeurXMLParseMessageRecu = require('./constructeurXMLParseMessageRecu');

class ConstructeurXMLParseRequeteRecue extends ConstructeurXMLParseMessageRecu {
  constructor() {
    super();
    this.codeDemarche = '';
  }

  avecCodeDemarche(codeDemarche) {
    this.codeDemarche = codeDemarche;
    return this;
  }

  construis() {
    return {
      QueryRequest: {
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
