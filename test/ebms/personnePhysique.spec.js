const PersonnePhysique = require('../../src/ebms/personnePhysique');

describe('Une personne physique', () => {
  it("doit s'afficher en XML", () => {
    const jonas = new PersonnePhysique(
      {
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
      <sdg:FamilyName>Garcia</sdg:FamilyName>
      <sdg:GivenName>Jose</sdg:GivenName>
      <sdg:DateOfBirth>1985-12-20</sdg:DateOfBirth>
    </sdg:Person>
  </rim:SlotValue>
</rim:Slot>
    `);
  });
});
