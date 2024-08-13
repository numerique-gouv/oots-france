const PersonnePhysique = require('../../src/ebms/personnePhysique');

describe('Une personne physique', () => {
  it("s'affiche en XML", () => {
    const personne = new PersonnePhysique({
      dateNaissance: '1999-02-25',
      genre: PersonnePhysique.MASCULIN,
      lieuNaissance: 'Paris, France',
      nomUsage: 'Dubois',
      prenoms: 'Rémi',
      prenomsNomNaissance: 'Rémi Dubois-Marin',
    });

    expect(personne.enXML()).toBe(`
<rim:Slot name="NaturalPerson">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Person>
      <sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>
      <sdg:FamilyName>Dubois</sdg:FamilyName>
      <sdg:GivenName>Rémi</sdg:GivenName>
      <sdg:DateOfBirth>1999-02-25</sdg:DateOfBirth>
      <sdg:BirthName>Rémi Dubois-Marin</sdg:BirthName>
      <sdg:PlaceOfBirth>Paris, France</sdg:PlaceOfBirth>
      <sdg:Gender>Male</sdg:Gender>
    </sdg:Person>
  </rim:SlotValue>
</rim:Slot>
    `);
  });

  it('indique une valeur par défaut pour le genre', () => {
    const personne = new PersonnePhysique();
    expect(personne.enXML()).toContain('<sdg:Gender>Unspecified</sdg:Gender>');
  });

  it('indique une valeur par défaut pour le nom de naissance', () => {
    const personne = new PersonnePhysique();
    expect(personne.enXML()).toContain('<sdg:BirthName></sdg:BirthName>');
  });

  it('indique une valeur par défaut pour le lieu de naissance', () => {
    const personne = new PersonnePhysique();
    expect(personne.enXML()).toContain('<sdg:PlaceOfBirth></sdg:PlaceOfBirth>');
  });
});
