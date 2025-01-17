const FORMATS_DISTRIBUTION = {
  FORMAT_PDF: 'application/pdf',
};

class TypeJustificatif {
  constructor(donnees = {}) {
    const { id, descriptions, formatDistribution } = donnees;
    this.id = id || 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000';
    this.descriptions = descriptions || {};
    this.formatDistribution = formatDistribution || FORMATS_DISTRIBUTION.FORMAT_PDF;
  }

  identifiantEtDescriptionsEnXML() {
    const descriptionsEnXML = () => Object
      .entries(this.descriptions)
      .map(([langue, description]) => `<sdg:Title lang="${langue}">${description}</sdg:Title>`);

    return `
<sdg:EvidenceTypeClassification>${this.id}</sdg:EvidenceTypeClassification>
${descriptionsEnXML()}
    `;
  }

  enXMLPourRequete() {
    return `
<rim:Slot name="EvidenceRequest">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:DataServiceEvidenceType xmlns="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0">
      <sdg:Identifier>00000000-0000-0000-0000-000000000000</sdg:Identifier>
      ${this.identifiantEtDescriptionsEnXML()}
      <sdg:DistributedAs>
        <sdg:Format>${this.formatDistribution}</sdg:Format>
      </sdg:DistributedAs>
    </sdg:DataServiceEvidenceType>
  </rim:SlotValue>
</rim:Slot>
    `;
  }

  enXMLPourReponse() {
    return this.identifiantEtDescriptionsEnXML();
  }
}

Object.assign(TypeJustificatif, FORMATS_DISTRIBUTION);
module.exports = TypeJustificatif;
