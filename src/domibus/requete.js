const MessageRecu = require('./messageRecu')
const CodeDemarche = require('../ebms/codeDemarche')
const ReponseErreur = require('../ebms/reponseErreur')
const PersonnePhysique = require('../ebms/personnePhysique')
const ReponseVerificationSysteme = require('../ebms/reponseVerificationSysteme')
const Requeteur = require('../ebms/requeteur')
const TypeJustificatif = require('../ebms/typeJustificatif')
const { ErreurMessageIllisible } = require('../erreurs')
const { valeurSlot } = require('../ebms/utils')

// Un slot peut être présent et son contenu inexploitable : `valeurSlot` ne
// vérifie que la présence. Sans cette garde, l'accès à la propriété absente
// lèverait un `TypeError`, qui n'est pas une `ErreurMessageIllisible` et
// laisserait donc le correspondant sans réponse au lieu du `EDM:ERR:0003` que
// les TDD prévoient pour une requête qu'on ne sait pas lire.
const exigeContenu = (valeur, description) => {
  if (typeof valeur === 'undefined') {
    throw new ErreurMessageIllisible(`${description} dans la requête reçue.`)
  }

  return valeur
}

class Requete extends MessageRecu {
  codeDemarche() {
    return valeurSlot('Procedure', this.xmlParse.QueryRequest)
  }

  beneficiaire() {
    const beneficiaire = exigeContenu(
      valeurSlot('NaturalPerson', this.xmlParse.QueryRequest.Query).Person,
      'Aucune personne physique sous le slot `NaturalPerson`',
    )

    return new PersonnePhysique({
      dateNaissance: beneficiaire.DateOfBirth,
      identifiantEidas: beneficiaire.Identifier?.['#text'],
      nom: beneficiaire.FamilyName,
      prenom: beneficiaire.GivenName,
    })
  }

  idRequete() {
    return this.xmlParse.QueryRequest['@_id']
  }

  reponse(config, donnees) {
    if (this.codeDemarche() === CodeDemarche.VERIFICATION_SYSTEME) {
      // Le seul format que la France sache produire est le PDF. En demander un
      // autre n'est pas une requête invalide : c'est une capacité facultative
      // que ce fournisseur ne supporte pas, ce que dit `EDM:ERR:0007`.
      if (donnees.typeJustificatif.formatDistribution !== TypeJustificatif.FORMAT_PDF) {
        const exception = ReponseErreur.UNSUPPORTED_CAPABILITY_EXCEPTION
        return new ReponseErreur(config, { ...donnees, exception })
      }

      return new ReponseVerificationSysteme(config, donnees)
    }

    const exception = ReponseErreur.OBJECT_NOT_FOUND_EXCEPTION
    return new ReponseErreur(config, { ...donnees, exception })
  }

  requeteur() {
    const requeteurs = valeurSlot('EvidenceRequester', this.xmlParse.QueryRequest).map(e => e.Agent)
    const requeteurJustificatif = exigeContenu(
      requeteurs.find(r => r?.Classification === 'ER'),
      'Aucun agent de classification `ER` sous le slot `EvidenceRequester`',
    )
    const id = Requete.idRequeteur(requeteurJustificatif)
    const nom = Requete.nomRequeteur(requeteurJustificatif)
    const typeId = Requete.typeIdRequeteur(requeteurJustificatif)
    const langue = Requete.langueRequeteur(requeteurJustificatif)

    return new Requeteur({}, {
      id, langue, nom, typeId,
    })
  }

  typeJustificatif() {
    const donneesTypeJustificatif = exigeContenu(
      valeurSlot('EvidenceRequest', this.xmlParse.QueryRequest.Query).DataServiceEvidenceType,
      'Aucun type de justificatif sous le slot `EvidenceRequest`',
    )
    const descriptions = []
      .concat(donneesTypeJustificatif.Title || {})
      .reduce((acc, description) => Object.assign(acc, { [description['@_lang']]: description['#text'] }), {})

    return new TypeJustificatif({
      id: donneesTypeJustificatif.EvidenceTypeClassification,
      descriptions,
      formatDistribution: exigeContenu(
        donneesTypeJustificatif.DistributedAs,
        'Aucun format de distribution sous le slot `EvidenceRequest`',
      ).Format,
    })
  }
}

module.exports = Requete
