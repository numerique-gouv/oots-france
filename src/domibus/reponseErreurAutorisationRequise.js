const MessageRecu = require('./messageRecu');
const { valeurSlot } = require('../ebms/utils');

class ReponseErreurAutorisationRequise extends MessageRecu {
  suiteConversation() {
    return valeurSlot('PreviewLocation', this.xmlParse.QueryResponse.Exception);
  }
}

module.exports = ReponseErreurAutorisationRequise;
