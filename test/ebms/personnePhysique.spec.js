const PersonnePhysique = require('../../src/ebms/personnePhysique');
const { parseXML, valeurSlot } = require('../../src/ebms/utils');

describe('Une personne physique', () => {
  it("doit s'afficher en XML", () => {
    const jonas = new PersonnePhysique(
      {
        identifiantEidas: 'DK/DE/123123123',
        nom: 'Garcia',
        prenom: 'Jose',
        dateNaissance: '1985-12-20',
      },
    );

    expect(jonas.enXML()).toBe(`
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
    `);
  });

  it("n'affiche pas la balise identifiant s'il n'y a pas d'identifiant renseigné", () => {
    const personneSansIdentifiantEidas = new PersonnePhysique();
    const xml = parseXML(personneSansIdentifiantEidas.enXML());
    const identifiantEidas = valeurSlot('NaturalPerson', xml).Person.Identifier;

    expect(identifiantEidas).toBeUndefined();
  });
});
