const ReponseErreur = require('./reponseErreur')
const { valeurSlot } = require('../ebms/utils')

// Une réponse en erreur comme les autres — même enveloppe, même code EDM —, à
// ceci près qu'elle n'interrompt pas la conversation : elle porte l'adresse de
// l'espace de prévisualisation où l'usager est invité à choisir.
class ReponseErreurAutorisationRequise extends ReponseErreur {
  suiteConversation() {
    return valeurSlot('PreviewLocation', this.xmlParse.QueryResponse.Exception)
  }
}

module.exports = ReponseErreurAutorisationRequise
