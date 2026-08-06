const Fournisseur = require('../../src/ebms/fournisseur')
const { parseXML, valeurSlot } = require('../../src/ebms/utils')

describe('Un fournisseur', () => {
  const fournisseur = new Fournisseur({
    pointAcces: {
      id: 'unIdentifiant',
      typeId: 'unType',
    },
    descriptions: {
      EN: 'some access point',
      FR: 'un point d\'accès',
    },
  })

  it('s\'affiche en XML pour une requête', () => {
    expect(fournisseur.enXMLPourRequete()).toBe(`
<rim:Slot name="EvidenceProvider">
  <rim:SlotValue xsi:type="rim:AnyValueType">
    <sdg:Agent>
      <sdg:Identifier schemeID="unType">unIdentifiant</sdg:Identifier>
      <sdg:Name lang="EN">some access point</sdg:Name>
      <sdg:Name lang="FR">un point d'accès</sdg:Name>
    </sdg:Agent>
  </rim:SlotValue>
</rim:Slot>
    `)
  })

  it('s\'affiche en XML pour une réponse, classé fournisseur de justificatif', () => {
    const xml = parseXML(`<r xmlns:rim="urn:oasis:names:tc:ebxml-regrep:xsd:rim:4.0">${fournisseur.enXMLPourReponse()}</r>`)

    const agent = valeurSlot('EvidenceProvider', xml.r)[0].Agent
    expect(agent.Identifier['@_schemeID']).toBe('unType')
    expect(agent.Identifier['#text']).toBe('unIdentifiant')
    expect(agent.Classification).toBe('EP')
  })

  it('s\'affiche en XML comme autorité émettrice', () => {
    const xml = parseXML(`<r>${fournisseur.enXMLAutoriteEmettrice()}</r>`)

    expect(xml.r.IssuingAuthority.Identifier['#text']).toBe('unIdentifiant')
    expect(xml.r.IssuingAuthority.Name[0]['#text']).toBe('some access point')
  })

  describe('français', () => {
    it('se construit depuis l\'identité qu\'on lui donne', () => {
      const fournisseurFrancais = Fournisseur.francais({
        id: '00000000000001',
        nom: 'Direction interministérielle du numérique',
      })

      expect(fournisseurFrancais.pointAcces.id).toBe('00000000000001')
      expect(fournisseurFrancais.pointAcces.typeId).toBe('urn:cef.eu:names:identifier:EAS:0009')
      expect(fournisseurFrancais.descriptions.FR).toBe('Direction interministérielle du numérique')
    })
  })
})
