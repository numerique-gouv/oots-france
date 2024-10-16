const MessageRecu = require('./messageRecu');
const CodeDemarche = require('../ebms/codeDemarche');
const ReponseErreur = require('../ebms/reponseErreur');
const ReponseVerificationSysteme = require('../ebms/reponseVerificationSysteme');
const Requeteur = require('../ebms/requeteur');
const { valeurSlot } = require('../ebms/utils');

class Requete extends MessageRecu {
  codeDemarche() {
    return valeurSlot('Procedure', this.xmlParse.QueryRequest).LocalizedString['@_value'];
  }

  reponse(config, donnees) {
    if (this.codeDemarche() === CodeDemarche.VERIFICATION_SYSTEME) {
      return new ReponseVerificationSysteme(config, donnees);
    }

    const exception = ReponseErreur.OBJECT_NOT_FOUND_EXCEPTION;
    return new ReponseErreur(config, { ...donnees, exception });
  }

  requeteur() {
    const requeteurs = valeurSlot('EvidenceRequester', this.xmlParse.QueryRequest).map((e) => e.Agent);
    const requeteurJustificatif = requeteurs.find((r) => r.Classification === 'ER');

    const idRequeteur = requeteurJustificatif.Identifier['#text']
      ?.toString();

    const nomRequeteur = []
      .concat(requeteurJustificatif.Name ?? [])
      ?.[0]
      ?.['#text'];

    return new Requeteur({ id: idRequeteur, nom: nomRequeteur });
  }
}

module.exports = Requete;
