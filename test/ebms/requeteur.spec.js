const Requeteur = require('../../src/ebms/requeteur');

describe('Un requêteur', () => {
  it("s'affiche en XML pour une requête", () => {
    const requeteur = new Requeteur({ id: '123456', nom: 'Un requêteur français' });

    expect(requeteur.enXMLPourRequete()).toBe(`
<rim:Slot name="EvidenceRequester">
  <rim:SlotValue xsi:type="rim:CollectionValueType" collectionType="urn:oasis:names:tc:ebxml-regrep:CollectionType:Set">
    <rim:Element xsi:type="rim:AnyValueType">
      <sdg:Agent>
        <sdg:Identifier schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR">123456</sdg:Identifier>
        <sdg:Name lang="FR">Un requêteur français</sdg:Name>
        <sdg:Classification>ER</sdg:Classification>
      </sdg:Agent>
    </rim:Element>
    <rim:Element xsi:type="rim:AnyValueType">
      <sdg:Agent>
        <sdg:Identifier schemeID="urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR">OOTSFRANCE</sdg:Identifier>
        <sdg:Name lang="EN">OOTS-France Intermediary Platform</sdg:Name>
        <sdg:Classification>IP</sdg:Classification>
      </sdg:Agent>
    </rim:Element>
  </rim:SlotValue>
</rim:Slot>
    `);
  });
});
