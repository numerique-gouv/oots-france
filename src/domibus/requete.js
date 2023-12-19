const MessageRecu = require('./messageRecu');
const ReponseErreur = require('../ebms/reponseErreur');
const CodeDemarche = require('../ebms/codeDemarche');

class Requete extends MessageRecu {
  codeDemarche() {
    return this.xmlParse.QueryRequest.Slot
      .find((slot) => slot['@_name'] === 'Procedure').SlotValue.Value.LocalizedString['@_value'];
  }

  reponse(idRequete, config) {
    const exception = this.codeDemarche() === CodeDemarche.VERIFICATION_SYSTEME
      ? ReponseErreur.QUERY_EXCEPTION
      : ReponseErreur.OBJECT_NOT_FOUND_EXCEPTION;
    return new ReponseErreur({ idRequete, exception }, config);
  }
}

module.exports = Requete;
