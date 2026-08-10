const MessageRecu = require('./messageRecu')
const { ErreurReponseRequete } = require('../erreurs')

class ReponseErreur extends MessageRecu {
  // Le code EDM de l'erreur reçue — `EDM:ERR:0002` et ses voisins. Le
  // chapitre 4.8 demande de le journaliser : c'est lui qui dit *pourquoi* un
  // échange n'a pas abouti, là où le message n'en donne que la formulation.
  codeErreur() {
    return this.xmlParse.QueryResponse.Exception['@_code']
  }

  suiteConversation() {
    const messageErreur = this.xmlParse.QueryResponse.Exception['@_message']
    throw new ErreurReponseRequete(messageErreur)
  }
}

module.exports = ReponseErreur
