const { parseXML, verifiePresenceSlot, valeurSlot } = require('../../src/ebms/utils')
const CodeDemarche = require('../../src/ebms/codeDemarche')
const Fournisseur = require('../../src/ebms/fournisseur')
const PersonnePhysique = require('../../src/ebms/personnePhysique')
const PointAcces = require('../../src/ebms/pointAcces')
const RequeteJustificatif = require('../../src/ebms/requeteJustificatif')
const Requeteur = require('../../src/ebms/requeteur')
const TypeJustificatif = require('../../src/ebms/typeJustificatif')

describe('La vue du message de requête d\'un justificatif', () => {
  const adaptateurUUID = {}
  const horodateur = {}
  const configurationRequete = { adaptateurUUID, horodateur }

  // Une requête sans requêteur ni fournisseur n'aurait pas d'identité de coin,
  // que les messages refusent désormais : ces deux-là tiennent lieu de décor.
  const requeteur = new Requeteur({}, { id: '00000000000002', nom: 'Un requêteur' })
  const fournisseurAllemand = new Fournisseur({
    pointAcces: { id: 'DE73524311', typeId: 'urn:cef.eu:names:identifier:EAS:9930' },
  })

  const nouvelleRequete = (donnees = {}) => new RequeteJustificatif(
    configurationRequete,
    {
      requeteur,
      fournisseur: fournisseurAllemand,
      destinataire: new PointAcces('AP_DE_01', 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots'),
      ...donnees,
    },
  )

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => ''
    horodateur.maintenant = () => ''
  })

  it('injecte un identifiant unique de requête', () => {
    adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111'
    const xml = parseXML(nouvelleRequete().corpsMessageEnXML())

    expect(xml.QueryRequest['@_id']).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111')
  })

  it('respecte la structure définie par OOTS', () => {
    const xml = parseXML(nouvelleRequete().corpsMessageEnXML())

    const scopeRechercheQueryRequest = xml.QueryRequest
    verifiePresenceSlot('SpecificationIdentifier', scopeRechercheQueryRequest)
    verifiePresenceSlot('IssueDateTime', scopeRechercheQueryRequest)
    verifiePresenceSlot('Procedure', scopeRechercheQueryRequest)
    verifiePresenceSlot('PossibilityForPreview', scopeRechercheQueryRequest)
    verifiePresenceSlot('ExplicitRequestGiven', scopeRechercheQueryRequest)
    verifiePresenceSlot('Requirements', scopeRechercheQueryRequest)
    verifiePresenceSlot('EvidenceRequester', scopeRechercheQueryRequest)
    verifiePresenceSlot('EvidenceProvider', scopeRechercheQueryRequest)

    const scopeRechercheQuery = xml.QueryRequest.Query
    verifiePresenceSlot('EvidenceRequest', scopeRechercheQuery)
    verifiePresenceSlot('NaturalPerson', scopeRechercheQuery)
    expect(scopeRechercheQuery['@_queryDefinition']).toEqual('DocumentQuery')

    expect(xml.QueryRequest.ResponseOption).toBeDefined()
    expect(xml.QueryRequest.ResponseOption['@_returnType']).toEqual('LeafClassWithRepositoryItem')
  })

  it('injecte la demande de prévisualisation', () => {
    const xml = parseXML(nouvelleRequete({ previsualisationRequise: false }).corpsMessageEnXML())

    expect(valeurSlot('PossibilityForPreview', xml.QueryRequest)).toBe(false)
  })

  it('annonce le requêteur et le fournisseur comme coins C1 et C4', () => {
    const xml = parseXML(nouvelleRequete().entete.enXML())
    const proprietes = xml.Messaging.UserMessage.MessageProperties.Property

    const expediteur = proprietes.find(p => p['@_name'] === 'originalSender')
    expect(expediteur['#text']).toBe('00000000000002')
    expect(expediteur['@_type']).toBe('urn:cef.eu:names:identifier:EAS:0009')

    const destinataireFinal = proprietes.find(p => p['@_name'] === 'finalRecipient')
    expect(destinataireFinal['#text']).toBe('DE73524311')
    expect(destinataireFinal['@_type']).toBe('urn:cef.eu:names:identifier:EAS:9930')
  })

  it('reprend l\'identifiant du document dans le CID du payload', () => {
    let compteur = 0
    adaptateurUUID.genereUUID = () => `00000000-0000-0000-0000-00000000000${compteur++}`

    const requeteJustificatif = nouvelleRequete()
    const xml = parseXML(requeteJustificatif.corpsMessageEnXML())

    const idDocument = xml.QueryRequest['@_id'].replace('urn:uuid:', '')
    expect(requeteJustificatif.idPayload).toContain(`cid:${idDocument}@`)
  })

  it('annonce la version du modèle d\'échange', () => {
    const xml = parseXML(nouvelleRequete().corpsMessageEnXML())

    expect(valeurSlot('SpecificationIdentifier', xml.QueryRequest)).toBe('oots-edm:v2.0')
  })

  it('injecte le code de la démarche administrative (en anglais, « procedure »)', () => {
    const xml = parseXML(nouvelleRequete({ codeDemarche: 'T3' }).corpsMessageEnXML())

    expect(valeurSlot('Procedure', xml.QueryRequest)).toBe('T3')
  })

  it('injecte le code de la vérification système sans le transformer en nombre', () => {
    const requete = nouvelleRequete({ codeDemarche: CodeDemarche.VERIFICATION_SYSTEME })
    const xml = parseXML(requete.corpsMessageEnXML())

    expect(valeurSlot('Procedure', xml.QueryRequest)).toBe('00')
  })

  it('injecte l\'identifiant de type de justificatif demandé', () => {
    const requete = nouvelleRequete({ typeJustificatif: new TypeJustificatif({ id: 'unIdentifiant' }) })
    const xml = parseXML(requete.corpsMessageEnXML())

    const demande = valeurSlot('EvidenceRequest', xml.QueryRequest.Query)
    expect(demande.DataServiceEvidenceType.EvidenceTypeClassification).toBe('unIdentifiant')
  })

  it('injecte le fournisseur', () => {
    const requete = nouvelleRequete({
      fournisseur: new Fournisseur({ pointAcces: { typeId: 'unType', id: 'unIdentifiant' } }),
    })
    const xml = parseXML(requete.corpsMessageEnXML())

    expect(valeurSlot('EvidenceProvider', xml.QueryRequest).Agent.Identifier['#text']).toBe('unIdentifiant')
  })

  it('injecte les données du bénéficiaire', () => {
    const requete = nouvelleRequete({
      beneficiaire: new PersonnePhysique({ nom: 'Durand', prenom: 'Sabine', dateNaissance: '1987-03-28' }),
    })
    const xml = parseXML(requete.corpsMessageEnXML())

    const { Person } = valeurSlot('NaturalPerson', xml.QueryRequest.Query)
    expect(Person.FamilyName).toBe('Durand')
    expect(Person.GivenName).toBe('Sabine')
    expect(Person.DateOfBirth).toBe('1987-03-28')
  })
})
