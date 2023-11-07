const MessageRecu = require('./messageRecu');

class ReponseErreurAutorisationRequise extends MessageRecu {
  suiteConversation() {
    return this.xmlParse.QueryResponse.Exception.Slot
      .find((slot) => slot['@_name'] === 'PreviewLocation').SlotValue.Value;
  }
}

module.exports = ReponseErreurAutorisationRequise;
