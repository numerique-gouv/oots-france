const MessageRecu = require('./messageRecu');
const ReponseErreur = require('../ebms/reponseErreur');
const ReponseVerificationSysteme = require('../ebms/reponseVerificationSysteme');
const CodeDemarche = require('../ebms/codeDemarche');

class Requete extends MessageRecu {
  codeDemarche() {
    return this.xmlParse.QueryRequest.Slot
      .find((slot) => slot['@_name'] === 'Procedure').SlotValue.Value.LocalizedString['@_value'];
  }

  reponse(config, donnees) {
    if (this.codeDemarche() === CodeDemarche.VERIFICATION_SYSTEME) {
      return new ReponseVerificationSysteme(config, donnees);
    }

    const exception = ReponseErreur.OBJECT_NOT_FOUND_EXCEPTION;
    return new ReponseErreur(config, { ...donnees, exception });
  }
}

module.exports = Requete;
