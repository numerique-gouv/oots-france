const MessageRecu = require('./messageRecu');
const CodeDemarche = require('../ebms/codeDemarche');
const ReponseErreur = require('../ebms/reponseErreur');
const PersonnePhysique = require('../ebms/personnePhysique');
const ReponseVerificationSysteme = require('../ebms/reponseVerificationSysteme');
const Requeteur = require('../ebms/requeteur');
const { valeurSlot } = require('../ebms/utils');

class Requete extends MessageRecu {
  codeDemarche() {
    return valeurSlot('Procedure', this.xmlParse.QueryRequest).LocalizedString['@_value'];
  }

  demandeur() {
    const demandeur = valeurSlot('NaturalPerson', this.xmlParse.QueryRequest.Query).Person;

    return new PersonnePhysique({
      dateNaissance: demandeur.DateOfBirth,
      identifiantEidas: demandeur.Identifier?.['#text'],
      nom: demandeur.FamilyName,
      prenom: demandeur.GivenName,
    });
  }

  idRequete() {
    return this.xmlParse.QueryRequest['@_id'];
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
    const id = Requete.idRequeteur(requeteurJustificatif);
    const nom = Requete.nomRequeteur(requeteurJustificatif);

    return new Requeteur({ id, nom });
  }
}

module.exports = Requete;
