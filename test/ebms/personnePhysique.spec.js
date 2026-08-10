const PersonnePhysique = require('../../src/ebms/personnePhysique')
const { parseXML, valeurSlot } = require('../../src/ebms/utils')

describe('Une personne physique', () => {
  it('s\'affiche en XML pour une requête', () => {
    const jose = new PersonnePhysique(
      {
        identifiantEidas: 'DK/DE/123123123',
        nom: 'Garcia',
        prenom: 'Jose',
        dateNaissance: '1985-12-20',
      },
    )

    expect(jose.enXMLPourRequete()).toBe(`
<rim:Slot name="NaturalPerson">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Person>
      <sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>

<sdg:Identifier schemeID="eidas">DK/DE/123123123</sdg:Identifier>
<sdg:FamilyName>Garcia</sdg:FamilyName>
<sdg:GivenName>Jose</sdg:GivenName>
<sdg:DateOfBirth>1985-12-20</sdg:DateOfBirth>

    </sdg:Person>
  </rim:SlotValue>
</rim:Slot>
    `)
  })

  it('n\'affiche pas la balise identifiant s\'il n\'y a pas d\'identifiant renseigné', () => {
    const personneSansIdentifiantEidas = new PersonnePhysique()
    const xml = parseXML(personneSansIdentifiantEidas.enXMLPourRequete())
    const identifiantEidas = valeurSlot('NaturalPerson', xml).Person.Identifier

    expect(identifiantEidas).toBeUndefined()
  })

  it('s\'affiche en XML pour une réponse', () => {
    const jose = new PersonnePhysique(
      {
        identifiantEidas: 'DK/DE/123123123',
        nom: 'Garcia',
        prenom: 'Jose',
        dateNaissance: '1985-12-20',
      },
    )

    expect(jose.enXMLPourReponse()).toBe(`
<sdg:NaturalPerson>
<sdg:Identifier schemeID="eidas">DK/DE/123123123</sdg:Identifier>
<sdg:FamilyName>Garcia</sdg:FamilyName>
<sdg:GivenName>Jose</sdg:GivenName>
<sdg:DateOfBirth>1985-12-20</sdg:DateOfBirth>
</sdg:NaturalPerson>
    `)
  })
  describe('sur son identifiant pour le journal', () => {
    // Le chapitre 4.8 demande de journaliser le sujet du justificatif.
    // L'identifiant eIDAS est la donnée la plus économe qui le désigne encore
    // sans ambiguïté : il se préfère à l'état civil chaque fois qu'il existe.
    it('préfère l\'identifiant eIDAS quand il est connu', () => {
      const jose = new PersonnePhysique({
        identifiantEidas: 'DK/DE/123123123',
        nom: 'Garcia',
        prenom: 'Jose',
        dateNaissance: '1985-12-20',
      })

      expect(jose.identifiantPourJournal()).toBe('DK/DE/123123123')
    })

    // Tant que le rapprochement d'identité n'existe pas, le bénéficiaire arrive
    // du requêteur sans identifiant : l'état civil est le seul recours.
    it('se rabat sur l\'état civil à défaut', () => {
      const jose = new PersonnePhysique({
        nom: 'Garcia',
        prenom: 'Jose',
        dateNaissance: '1985-12-20',
      })

      expect(jose.identifiantPourJournal()).toBe('Garcia Jose (1985-12-20)')
    })
  })
})
