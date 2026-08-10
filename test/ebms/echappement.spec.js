const { echappeXML } = require('../../src/ebms/echappement')

describe('L\'échappement XML', () => {
  it('laisse un texte ordinaire intact', () => {
    expect(echappeXML('Ministère de l\'enseignement supérieur')).toBe('Ministère de l\'enseignement supérieur')
  })

  it('échappe les caractères qui ouvriraient une balise ou un attribut', () => {
    expect(echappeXML('a<b>c&d"e')).toBe('a&lt;b&gt;c&amp;d&quot;e')
  })

  // fast-xml-parser décode les entités à la lecture : un identifiant reçu peut
  // donc contenir de vrais chevrons, qu'il ne faut pas réémettre tels quels.
  it('neutralise une tentative d\'injection venue d\'un message reçu', () => {
    const identifiantHostile = 'A"/><eb:Property name="injecte">oui</eb:Property><x y="'

    const echappe = echappeXML(identifiantHostile)

    expect(echappe).not.toContain('<eb:Property')
    expect(echappe).not.toContain('"')
  })

  it('rend une chaîne vide plutôt que le mot « undefined »', () => {
    expect(echappeXML(undefined)).toBe('')
    expect(echappeXML(null)).toBe('')
  })

  it('accepte ce qui n\'est pas une chaîne', () => {
    expect(echappeXML(42)).toBe('42')
    expect(echappeXML(false)).toBe('false')
  })
})
