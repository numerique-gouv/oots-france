const MessageRecu = require('./messageRecu');

class Requete extends MessageRecu {
  codeDemarche() {
    return this.xmlParse.QueryRequest.Slot
      .find((slot) => slot['@_name'] === 'Procedure').SlotValue.Value.LocalizedString['@_value'];
  }
}

module.exports = Requete;
