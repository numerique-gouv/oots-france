const { echappeXML } = require('./echappement')
class PersonnePhysique {
  constructor(donnees = {}) {
    this.identifiantEidas = donnees.identifiantEidas
    this.nom = donnees.nom
    this.prenom = donnees.prenom
    this.dateNaissance = donnees.dateNaissance
  }

  attributsEnXML() {
    const identifiantEidasEnXML = typeof this.identifiantEidas !== 'undefined'
      ? `<sdg:Identifier schemeID="eidas">${echappeXML(this.identifiantEidas)}</sdg:Identifier>`
      : ''

    return `
${identifiantEidasEnXML}
<sdg:FamilyName>${echappeXML(this.nom)}</sdg:FamilyName>
<sdg:GivenName>${echappeXML(this.prenom)}</sdg:GivenName>
<sdg:DateOfBirth>${echappeXML(this.dateNaissance)}</sdg:DateOfBirth>
`
  }

  enXMLPourReponse() {
    return `
<sdg:NaturalPerson>${this.attributsEnXML()}</sdg:NaturalPerson>
    `
  }

  enXMLPourRequete() {
    return `
<rim:Slot name="NaturalPerson">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Person>
      <sdg:LevelOfAssurance>High</sdg:LevelOfAssurance>
${this.attributsEnXML()}
    </sdg:Person>
  </rim:SlotValue>
</rim:Slot>
    `
  }

  identifiantEidasEnXML() {
    return typeof this.identifiantEidas !== 'undefined'
      ? `<sdg:Identifier schemeID="eidas">${echappeXML(this.identifiantEidas)}</sdg:Identifier>`
      : ''
  }
}

module.exports = PersonnePhysique
