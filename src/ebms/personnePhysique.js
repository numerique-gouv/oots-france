class PersonnePhysique {
  constructor(donnees = {}) {
    this.nom = donnees.nom;
    this.prenom = donnees.prenom;
    this.dateNaissance = donnees.dateNaissance;
  }

  enXML() {
    return `
<rim:Slot name="NaturalPerson">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Person>
      <sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>
      <sdg:FamilyName>${this.nom}</sdg:FamilyName>
      <sdg:GivenName>${this.prenom}</sdg:GivenName>
      <sdg:DateOfBirth>${this.dateNaissance}</sdg:DateOfBirth>
    </sdg:Person>
  </rim:SlotValue>
</rim:Slot>
    `;
  }
}

module.exports = PersonnePhysique;
