const TypeJustificatif = require('../../src/ebms/typeJustificatif');

describe('Le type de justificatif', () => {
  it("s'affiche en XML", () => {
    const typeJustificatif = new TypeJustificatif({
      id: 'unIdentifiant',
      descriptions: { EN: 'someType' },
      formatDistribution: TypeJustificatif.FORMAT_PDF,
    });

    expect(typeJustificatif.enXMLPourRequete()).toBe(`
<rim:Slot name="EvidenceRequest">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:DataServiceEvidenceType xmlns="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0">
      <sdg:Identifier>00000000-0000-0000-0000-000000000000</sdg:Identifier>
      
<sdg:EvidenceTypeClassification>unIdentifiant</sdg:EvidenceTypeClassification>
<sdg:Title lang="EN">someType</sdg:Title>
    
      <sdg:DistributedAs>
        <sdg:Format>application/pdf</sdg:Format>
      </sdg:DistributedAs>
    </sdg:DataServiceEvidenceType>
  </rim:SlotValue>
</rim:Slot>
    `);
  });
});
