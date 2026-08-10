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

  // Le sujet du justificatif, tel que le chapitre 4.8 demande de le journaliser
  // (« Evidence Subject information »).
  //
  // L'identifiant eIDAS suffit et se préfère à l'état civil : c'est la donnée
  // la plus économe qui désigne encore la personne sans ambiguïté. Faute de
  // rapprochement d'identité — le bénéficiaire est aujourd'hui transmis par le
  // requêteur, sans identifiant —, l'état civil reste le seul recours. Le jour
  // où l'identifiant sera toujours présent, cette seconde branche disparaîtra.
  identifiantPourJournal() {
    return this.identifiantEidas ?? `${this.nom} ${this.prenom} (${this.dateNaissance})`
  }

  identifiantEidasEnXML() {
    return typeof this.identifiantEidas !== 'undefined'
      ? `<sdg:Identifier schemeID="eidas">${echappeXML(this.identifiantEidas)}</sdg:Identifier>`
      : ''
  }
}

module.exports = PersonnePhysique
