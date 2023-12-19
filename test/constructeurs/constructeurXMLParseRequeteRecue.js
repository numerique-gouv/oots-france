class ConstructeurXMLParseRequeteRecue {
  constructor() {
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
        ],
      },
    };
  }
}

module.exports = ConstructeurXMLParseRequeteRecue;
