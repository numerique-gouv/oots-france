const Requeteur = require('../../src/ebms/requeteur');

describe('Un requêteur', () => {
  const adaptateurChiffrement = {};

  beforeEach(() => {
    adaptateurChiffrement.dechiffreJWE = () => Promise.resolve();
  });

  it("s'affiche en XML pour une requête", () => {
    const requeteur = new Requeteur({}, { id: '123456', nom: 'Un requêteur français' });

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

  it('déchiffre le JWE contenant les infos du bénéficiaire', () => {
    expect.assertions(2);

    adaptateurChiffrement.dechiffreJWE = (jwe, urlJWKS) => {
      expect(jwe).toBe('abcd');
      expect(urlJWKS).toBe('http://example.com/auth/cles_publiques');
      return Promise.resolve({});
    };

    const requeteur = new Requeteur({ adaptateurChiffrement }, { url: 'http://example.com' });
    return requeteur.beneficiaire('abcd');
  });

  it('retourne la personne physique associée aux infos bénéficiaire déchiffrées', () => {
    adaptateurChiffrement.dechiffreJWE = () => Promise.resolve({ dateNaissance: '1965-11-25', nomUsage: 'Dupont', prenom: 'Sophie' });

    const requeteur = new Requeteur({ adaptateurChiffrement }, {});
    return requeteur.beneficiaire('abcd')
      .then((b) => {
        expect(b.dateNaissance).toBe('1965-11-25');
        expect(b.nom).toBe('Dupont');
        expect(b.prenom).toBe('Sophie');
      });
  });
});
