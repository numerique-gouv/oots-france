const GENRE = {
  MASCULIN: 'Male',
  FEMININ: 'Female',
  NON_SPECIFIE: 'Unspecified',
};

class PersonnePhysique {
  constructor(donnees = {}) {
    this.dateNaissance = donnees.dateNaissance;
    this.genre = donnees.genre || GENRE.NON_SPECIFIE;
    this.lieuNaissance = donnees.lieuNaissance || '';
    this.nomUsage = donnees.nomUsage;
    this.prenoms = donnees.prenoms;
    this.prenomsNomNaissance = donnees.prenomsNomNaissance || '';
  }

  enXML() {
    return `
<rim:Slot name="NaturalPerson">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Person>
      <sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>
      <sdg:FamilyName>${this.nomUsage}</sdg:FamilyName>
      <sdg:GivenName>${this.prenoms}</sdg:GivenName>
      <sdg:DateOfBirth>${this.dateNaissance}</sdg:DateOfBirth>
      <sdg:BirthName>${this.prenomsNomNaissance}</sdg:BirthName>
      <sdg:PlaceOfBirth>${this.lieuNaissance}</sdg:PlaceOfBirth>
      <sdg:Gender>${this.genre}</sdg:Gender>
    </sdg:Person>
  </rim:SlotValue>
</rim:Slot>
    `;
  }
}

Object.assign(PersonnePhysique, GENRE);
module.exports = PersonnePhysique;
