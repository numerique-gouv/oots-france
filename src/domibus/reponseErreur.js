const MessageRecu = require('./messageRecu');
const { ErreurReponseRequete } = require('../erreurs');

class ReponseErreur extends MessageRecu {
  suiteConversation() {
    const messageErreur = this.xmlParse.QueryResponse.Exception['@_message'];
    throw new ErreurReponseRequete(messageErreur);
  }
}

module.exports = ReponseErreur;
