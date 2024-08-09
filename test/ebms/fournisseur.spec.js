const Fournisseur = require('../../src/ebms/fournisseur');

describe('Un fournisseur', () => {
  it("s'affiche en XML", () => {
    const fournisseur = new Fournisseur({
      pointAcces: {
        id: 'unIdentifiant',
        typeId: 'unType',
      },
      descriptions: {
        EN: 'some access point',
        FR: "un point d'accès",
      },
    });

    expect(fournisseur.enXML()).toBe(`
<rim:Slot name="EvidenceProvider">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Agent>
      <sdg:Identifier schemeID="unType">unIdentifiant</sdg:Identifier>
      <sdg:Name lang="EN">some access point</sdg:Name>
      <sdg:Name lang="FR">un point d'accès</sdg:Name>
    </sdg:Agent>
  </rim:SlotValue>
</rim:Slot>
    `);
  });
});
