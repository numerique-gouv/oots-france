const ReponseDomibus = require('./reponseDomibus');

class ReponseEnvoiMessage extends ReponseDomibus {
  idMessage() {
    return this.xml['soap:Envelope']['soap:Body']['ns4:submitResponse'].messageID;
  }
}

module.exports = ReponseEnvoiMessage;
