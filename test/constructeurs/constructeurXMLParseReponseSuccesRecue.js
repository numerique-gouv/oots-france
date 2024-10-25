const ConstructeurXMLParseMessageRecu = require('./constructeurXMLParseMessageRecu');

class ConstructeurXMLParseReponseSuccesRecue extends ConstructeurXMLParseMessageRecu {
  construis() {
    return {
      QueryResponse: {
        Slot: [
          {
            '@_name': 'EvidenceRequester',
            SlotValue: {
              '@_type': 'rim:AnyValueType',
              Agent: {
                Identifier: { '#text': this.requeteur.id },
                Name: [
                  { '@_lang': 'FR', '#text': this.requeteur.nom },
                  { '@_lang': 'EN', '#text': 'Some translation' },
                ],
              },
            },
          },
        ],
      },
    };
  }
}

module.exports = ConstructeurXMLParseReponseSuccesRecue;
