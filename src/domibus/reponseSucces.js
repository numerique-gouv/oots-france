const MessageRecu = require('./messageRecu');
const Requeteur = require('../ebms/requeteur');
const { valeurSlot } = require('../ebms/utils');

class ReponseSucces extends MessageRecu {
  requeteur() {
    const requeteur = valeurSlot('EvidenceRequester', this.xmlParse.QueryResponse).Agent;
    const id = ReponseSucces.idRequeteur(requeteur);
    const nom = ReponseSucces.nomRequeteur(requeteur);

    return new Requeteur({ id, nom });
  }
}

module.exports = ReponseSucces;
