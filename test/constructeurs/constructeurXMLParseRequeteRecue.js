const ConstructeurXMLParseMessageRecu = require('./constructeurXMLParseMessageRecu')
const PersonnePhysique = require('../../src/ebms/personnePhysique')
const TypeJustificatif = require('../../src/ebms/typeJustificatif')

class ConstructeurXMLParseRequeteRecue extends ConstructeurXMLParseMessageRecu {
  constructor() {
    super()
    this.codeDemarche = ''
    this.idRequete = ''
    this.beneficiaire = new PersonnePhysique()
    this.typeJustificatif = new TypeJustificatif()
    this.contenusRetires = []
  }

  // Le slot reste en place, mais ce qu'on y cherche disparaît : c'est le cas
  // qu'un simple `sansSlot` ne sait pas produire, et celui contre lequel les
  // gardes de `Requete` protègent.
  sansContenu(nom) {
    this.contenusRetires.push(nom)
    return this
  }

  contenu(nom, valeur) {
    return this.contenusRetires.includes(nom) ? undefined : valeur
  }

  avecCodeDemarche(codeDemarche) {
    this.codeDemarche = codeDemarche
    return this
  }

  avecDemandeur(donnees) {
    this.beneficiaire = new PersonnePhysique(donnees)
    return this
  }

  avecIdRequete(id) {
    this.idRequete = id
    return this
  }

  avecTypeJustificatif(donnees) {
    this.typeJustificatif = new TypeJustificatif(donnees)
    return this
  }

  construis() {
    return {
      QueryRequest: {
        '@_id': this.idRequete,
        'Slot': [
          {
            '@_name': 'SpecificationIdentifier',
            'SlotValue': {
              // …
            },
          },
          {
            '@_name': 'Procedure',
            'SlotValue': {
              '@_type': 'rim:StringValueType',
              'Value': this.codeDemarche,
            },
          },
          {
            '@_name': 'EvidenceRequester',
            'SlotValue': {
              '@_type': 'rim:CollectionValueType',
              // L'élément reste dans la collection, vidé de son agent : c'est
              // la forme la plus exigeante pour la lecture, qui doit survivre
              // à un élément sans `Agent` avant de constater qu'aucun n'est
              // classé `ER`.
              'Element': [
                {
                  Agent: this.contenu('AgentRequeteur', {
                    Identifier: { '#text': this.requeteur.id },
                    Name: [
                      { '@_lang': 'FR', '#text': this.requeteur.nom },
                      { '@_lang': 'EN', '#text': 'Some translation' },
                    ],
                    Classification: 'ER',
                  }),
                },
                {
                  Agent: {
                    Identifier: { '#text': 'OOTSFRANCE' },
                    Classification: 'IP',
                  },
                },
              ],
            },
          },
        ],
        'Query': {
          Slot: [
            {
              '@_name': 'NaturalPerson',
              'SlotValue': {
                '@_type': 'rim:AnyValueType',
                'Person': this.contenu('Person', {
                  Identifier: this.beneficiaire.identifiantEidas && {
                    '@_schemeID': 'eidas',
                    '#text': this.beneficiaire.identifiantEidas,
                  },
                  FamilyName: this.beneficiaire.nom,
                  GivenName: this.beneficiaire.prenom,
                  DateOfBirth: this.beneficiaire.dateNaissance,
                }),
              },
            },
            {
              '@_name': 'EvidenceRequest',
              'SlotValue': {
                '@_type': 'rim:AnyValueType',
                'DataServiceEvidenceType': this.contenu('DataServiceEvidenceType', {
                  Identifier: '00000000-0000-0000-0000-000000000000',
                  EvidenceTypeClassification: this.typeJustificatif.id,
                  Title: Object.entries(this.typeJustificatif.descriptions || {})
                    .map(([k, v]) => ({ '@_lang': k, '#text': v })),
                  DistributedAs: this.contenu('DistributedAs', {
                    Format: this.typeJustificatif.formatDistribution,
                  }),
                }),
              },
            },
          ],
        },
      },
    }
  }
}

module.exports = ConstructeurXMLParseRequeteRecue
