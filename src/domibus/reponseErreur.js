const MessageRecu = require('./messageRecu')
const { ErreurReponseRequete } = require('../erreurs')

class ReponseErreur extends MessageRecu {
  suiteConversation() {
    const exception = this.xmlParse.QueryResponse.Exception
    const messageErreur = exception['@_message']

    // Le code distingue les huit erreurs des TDD, là où le message seul les
    // confond : sans lui, un délai dépassé et une référence non résolue se
    // lisent pareil dans les journaux.
    const codeErreur = exception['@_code']
    throw new ErreurReponseRequete(
      typeof codeErreur === 'undefined' ? messageErreur : `${codeErreur} : ${messageErreur}`,
    )
  }
}

module.exports = ReponseErreur
