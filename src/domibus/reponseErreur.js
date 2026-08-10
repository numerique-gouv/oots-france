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
