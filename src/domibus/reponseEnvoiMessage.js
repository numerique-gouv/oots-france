const ReponseDomibus = require('./reponseDomibus');

class ReponseEnvoiMessage extends ReponseDomibus {
  idMessage() {
    return this.xml.Envelope.Body.submitResponse.messageID;
  }
}

module.exports = ReponseEnvoiMessage;
