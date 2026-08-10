const { exigeIdentite, identiteEbms } = require('../../src/ebms/identiteEbms')
const { ErreurConfiguration } = require('../../src/erreurs')

describe('L\'identité ebMS d\'une organisation', () => {
  const complete = { id: '00000000000001', typeId: 'urn:cef.eu:names:identifier:EAS:0009' }

  it('se laisse lire quand elle est complète', () => {
    expect(identiteEbms(complete, 'Le fournisseur')).toEqual(complete)
  })

  // Ces trois formes produiraient toutes un `undefined` ou un vide dans
  // l'entête, que Domibus accepte : la propriété y est bien présente.
  it.each([
    ['sans identifiant', { typeId: 'urn:type' }],
    ['sans schéma', { id: '00000000000001' }],
    ['avec un identifiant vide', { id: '', typeId: 'urn:type' }],
    ['avec un schéma vide', { id: '00000000000001', typeId: '' }],
    ['avec un schéma fait d\'espaces', { id: '00000000000001', typeId: '   ' }],
  ])('est refusée %s', (_, identite) => {
    expect(() => identiteEbms(identite, 'Le fournisseur')).toThrow(ErreurConfiguration)
  })

  it('nomme dans l\'erreur ce dont l\'identité manque', () => {
    expect(() => identiteEbms({}, 'Le requêteur')).toThrow(/Le requêteur/)
  })

  describe('quand on l\'exige d\'un porteur', () => {
    it('la tire du porteur', () => {
      const porteur = { identiteEbms: () => complete }

      expect(exigeIdentite(porteur, 'Le fournisseur')).toEqual(complete)
    })

    it.each([['absent', undefined], ['nul', null]])('refuse un porteur %s', (_, porteur) => {
      expect(() => exigeIdentite(porteur, 'Le requêteur')).toThrow(ErreurConfiguration)
    })
  })
})
