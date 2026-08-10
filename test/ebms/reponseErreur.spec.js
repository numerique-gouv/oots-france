const { parseXML, verifiePresenceSlot, valeurSlot } = require('../../src/ebms/utils')
const Fournisseur = require('../../src/ebms/fournisseur')
const ReponseErreur = require('../../src/ebms/reponseErreur')
const Requeteur = require('../../src/ebms/requeteur')
const { ErreurConfiguration } = require('../../src/erreurs')

describe('Une réponse EBMS en erreur', () => {
  const adaptateurUUID = {}
  const horodateur = {}
  // Le fournisseur que `server.js` câble dans la configuration : les réponses
  // s'en servent par défaut, et les tests peuvent le passer explicitement.
  const fournisseur = Fournisseur.francais({ id: '00000000000001', nom: 'Un fournisseur français' })
  const config = { adaptateurUUID, fournisseurFrancais: fournisseur, horodateur }
  // Le requêteur est le coin C4 de la réponse : sans lui, l'entête n'a pas de
  // destinataire final et le message est refusé.
  const requeteur = new Requeteur({}, { id: 'BR_SI_01', nom: 'Un requêteur slovène', typeId: 'urn:cef.eu:names:identifier:EAS:0204' })

  const nouvelleErreur = (donnees = {}) => new ReponseErreur(config, { requeteur, ...donnees })

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => ''
    horodateur.maintenant = () => ''
  })

  it('injecte l\'identifiant unique de requête', () => {
    const reponse = nouvelleErreur({ idRequete: 'urn:uuid:11111111-1111-1111-1111-111111111111' })

    const xml = parseXML(reponse.corpsMessageEnXML())
    const idRequete = xml.QueryResponse['@_requestId']
    expect(idRequete).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111')
  })

  it('contient une section `Exception`', () => {
    const reponse = nouvelleErreur({
      exception: {
        type: 'unType',
        message: 'Un message',
        severite: 'unCodeSeverite',
        code: 'unCodeException',
      },
    })

    const xml = parseXML(reponse.corpsMessageEnXML())
    const sectionException = xml.QueryResponse.Exception
    expect(sectionException).toBeDefined()
    expect(sectionException['@_type']).toEqual('unType')
    expect(sectionException['@_message']).toEqual('Un message')
    expect(sectionException['@_severity']).toEqual('unCodeSeverite')
    expect(sectionException['@_code']).toEqual('unCodeException')
  })

  describe('dans la section `Exception`', () => {
    it('est horodatée', () => {
      horodateur.maintenant = () => '2023-09-30T14:30:00.000Z'
      const reponse = nouvelleErreur()

      const xml = parseXML(reponse.corpsMessageEnXML())
      const horodatage = valeurSlot('Timestamp', xml.QueryResponse.Exception)
      expect(horodatage).toEqual('2023-09-30T14:30:00.000Z')
    })
  })

  it('annonce la version du modèle d\'échange', () => {
    const reponse = nouvelleErreur()
    const xml = parseXML(reponse.corpsMessageEnXML())

    verifiePresenceSlot('SpecificationIdentifier', xml.QueryResponse)
    expect(valeurSlot('SpecificationIdentifier', xml.QueryResponse)).toBe('oots-edm:v2.0')
  })

  describe('dans la section `EvidenceResponseIdentifier`', () => {
    it('est identifiée par un UUID', () => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111'

      const reponse = nouvelleErreur()
      const xml = parseXML(reponse.corpsMessageEnXML())

      const idReponse = valeurSlot('EvidenceResponseIdentifier', xml.QueryResponse)
      expect(idReponse).toEqual('11111111-1111-1111-1111-111111111111')
    })
  })

  it('décrit le fournisseur de l\'erreur, classé `ERRP`', () => {
    const reponse = nouvelleErreur({ fournisseur })
    const xml = parseXML(reponse.corpsMessageEnXML())

    verifiePresenceSlot('ErrorProvider', xml.QueryResponse)
    const { Agent } = valeurSlot('ErrorProvider', xml.QueryResponse)
    expect(Agent.Identifier['#text']).toBe('00000000000001')
    expect(Agent.Name['#text']).toBe('Un fournisseur français')
    expect(Agent.Classification).toBe('ERRP')
  })

  it('décrit le requêteur quand il est connu', () => {
    const requeteur = new Requeteur({}, { id: 'abcdef', nom: 'Un requêteur' })
    const reponse = nouvelleErreur({ fournisseur, requeteur })
    const xml = parseXML(reponse.corpsMessageEnXML())

    const { Agent } = valeurSlot('EvidenceRequester', xml.QueryResponse)
    expect(Agent.Identifier['#text']).toBe('abcdef')
    expect(Agent.Name['#text']).toBe('Un requêteur')
  })

  // Le requêteur est le destinataire final de la réponse : sans lui, le message
  // n'irait nulle part. Mieux vaut renoncer à l'émettre que l'adresser à
  // « undefined », que Domibus accepterait.
  it('refuse d\'être construite sans requêteur', () => {
    expect(() => new ReponseErreur(config, { fournisseur }))
      .toThrow(ErreurConfiguration)
  })
})
