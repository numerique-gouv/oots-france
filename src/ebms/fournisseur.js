const Adresse = require('./adresse')
const { echappeXML } = require('./echappement')
const { identiteEbms } = require('./identiteEbms')
const { SCHEME_ID_FRANCAIS } = require('./schemeIdentifiant')

class Fournisseur {
  // L'identité vient de `adaptateurEnvironnement.identiteFournisseurFrancais()`,
  // qui la valide : elle est injectée depuis `server.js` plutôt que lue ici,
  // pour qu'une configuration incomplète arrête le démarrage au lieu de partir
  // en `undefined` dans chaque réponse.
  static francais({ id, nom }) {
    return new Fournisseur({
      pointAcces: { id, typeId: SCHEME_ID_FRANCAIS },
      descriptions: { FR: nom },
    })
  }

  constructor(donnees = {}) {
    const { pointAcces = {}, descriptions = {} } = donnees
    this.pointAcces = pointAcces
    this.descriptions = descriptions
    // Toujours française : l'adresse n'accompagne que les agents `EP` et
    // `ERRP`, tenus par le fournisseur français. Celui d'un autre État membre
    // n'en porte pas dans nos requêtes.
    this.adresse = new Adresse()
  }

  identiteEbms(quoi = 'Le fournisseur') {
    return identiteEbms(this.pointAcces, quoi)
  }

  identifiantEtNomEnXML() {
    const descriptionsEnXML = Object.entries(this.descriptions)
      .map(([langue, description]) => `<sdg:Name lang="${echappeXML(langue)}">${echappeXML(description)}</sdg:Name>`)
      .join('\n      ')

    return `<sdg:Identifier schemeID="${echappeXML(this.pointAcces.typeId)}">${echappeXML(this.pointAcces.id)}</sdg:Identifier>
      ${descriptionsEnXML}`
  }

  enXMLPourRequete() {
    return `
<rim:Slot name="EvidenceProvider">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Agent>
      ${this.identifiantEtNomEnXML()}
    </sdg:Agent>
  </rim:SlotValue>
</rim:Slot>
    `
  }

  enXMLPourReponse() {
    return `
<rim:Slot name="EvidenceProvider">
  <rim:SlotValue xsi:type="rim:CollectionValueType" collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
    <rim:Element xsi:type="rim:AnyValueType">
      <sdg:Agent>
        ${this.identifiantEtNomEnXML()}
        ${this.adresse.enXML()}
        <sdg:Classification>EP</sdg:Classification>
      </sdg:Agent>
    </rim:Element>
  </rim:SlotValue>
</rim:Slot>
    `
  }

  enXMLPourErreur() {
    return `
<rim:Slot name="ErrorProvider">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Agent>
      ${this.identifiantEtNomEnXML()}
      ${this.adresse.enXML()}
      <sdg:Classification>ERRP</sdg:Classification>
    </sdg:Agent>
  </rim:SlotValue>
</rim:Slot>
    `
  }

  enXMLAutoriteEmettrice() {
    return `<sdg:IssuingAuthority>
              ${this.identifiantEtNomEnXML()}
            </sdg:IssuingAuthority>`
  }

  idPointAcces() {
    return this.pointAcces.id
  }
}

module.exports = Fournisseur
