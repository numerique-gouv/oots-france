const ConstructeurXMLParseMessageRecu = require('./constructeurXMLParseMessageRecu');
const PersonnePhysique = require('../../src/ebms/personnePhysique');

class ConstructeurXMLParseRequeteRecue extends ConstructeurXMLParseMessageRecu {
  constructor() {
    super();
    this.codeDemarche = '';
    this.idRequete = '';
    this.demandeur = new PersonnePhysique();
  }

  avecCodeDemarche(codeDemarche) {
    this.codeDemarche = codeDemarche;
    return this;
  }

  avecDemandeur(donnees) {
    this.demandeur = new PersonnePhysique(donnees);
    return this;
  }

  avecIdRequete(id) {
    this.idRequete = id;
    return this;
  }

  construis() {
    return {
      QueryRequest: {
        '@_id': this.idRequete,
        Slot: [
          {
            '@_name': 'SpecificationIdentifier',
            SlotValue: {
              // …
            },
          },
          {
            '@_name': 'Procedure',
            SlotValue: {
              Value: {
                LocalizedString: {
                  '@_value': this.codeDemarche,
                },
              },
            },
          },
          {
            '@_name': 'EvidenceRequester',
            SlotValue: {
              '@_type': 'rim:CollectionValueType',
              Element: [
                {
                  Agent: {
                    Identifier: { '#text': this.requeteur.id },
                    Name: [
                      { '@_lang': 'FR', '#text': this.requeteur.nom },
                      { '@_lang': 'EN', '#text': 'Some translation' },
                    ],
                    Classification: 'ER',
                  },
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
        Query: {
          Slot: [
            {
              '@_name': 'NaturalPerson',
              SlotValue: {
                '@_type': 'rim:AnyValueType',
                Person: {
                  Identifier: this.demandeur.identifiantEidas && {
                    '@_schemeID': 'eidas',
                    '#text': this.demandeur.identifiantEidas,
                  },
                  FamilyName: this.demandeur.nom,
                  GivenName: this.demandeur.prenom,
                  DateOfBirth: this.demandeur.dateNaissance,
                },
              },
            },
          ],
        },
      },
    };
  }
}

module.exports = ConstructeurXMLParseRequeteRecue;
