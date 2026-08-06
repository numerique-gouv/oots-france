const Adresse = require('../../src/ebms/adresse')
const { parseXML } = require('../../src/ebms/utils')

describe('Une adresse d\'agent', () => {
  it('porte la France par défaut', () => {
    const xml = parseXML(`<r>${new Adresse().enXML()}</r>`)

    expect(xml.r.Address.AdminUnitLevel1).toBe('FR')
  })

  it('porte le pays qu\'on lui donne', () => {
    const xml = parseXML(`<r>${new Adresse('DE').enXML()}</r>`)

    expect(xml.r.Address.AdminUnitLevel1).toBe('DE')
  })
})
