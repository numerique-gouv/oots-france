class Fournisseur {
  constructor(donnees = {}) {
    const { pointAcces = {}, descriptions = {} } = donnees;
    this.pointAcces = pointAcces;
    this.descriptions = descriptions;
  }

  enXML() {
    const descriptionsEnXML = () => Object.entries(this.descriptions)
      .map(([langue, description]) => `<sdg:Name lang="${langue}">${description}</sdg:Name>`)
      .join('\n      ');

    return `
<rim:Slot name="EvidenceProvider">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Agent>
      <sdg:Identifier schemeID="${this.pointAcces.typeId}">${this.pointAcces.id}</sdg:Identifier>
      ${descriptionsEnXML()}
    </sdg:Agent>
  </rim:SlotValue>
</rim:Slot>
    `;
  }

  idPointAcces() {
    return this.pointAcces.id;
  }
}

module.exports = Fournisseur;
