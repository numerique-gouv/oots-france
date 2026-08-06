const { parseXML } = require('../../src/ebms/utils')
const EnteteRequete = require('../../src/ebms/enteteRequete')
const PointAcces = require('../../src/ebms/pointAcces')

describe('l\'entête EBMS de requête', () => {
  const adaptateurUUID = {}
  const horodateur = {}
  const destinataire = new PointAcces('id', 'urn:type')
  // L'entête refuse une identité de coin absente : ces deux-là la fournissent.
  const coins = {
    emetteurOriginal: { id: '00000000000002', typeId: 'urn:cef.eu:names:identifier:EAS:0009' },
    destinataireFinal: { id: 'DE73524311', typeId: 'urn:cef.eu:names:identifier:EAS:9930' },
  }
  let suffixe

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => ''
    horodateur.maintenant = () => ''
    suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS
  })

  afterEach(() => {
    process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS = suffixe
  })

  it('suit la structure EMBS', () => {
    const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur }, { destinataire, ...coins })
    const xml = parseXML(enteteEBMS.enXML())
    const userMessageInfos = xml.Messaging.UserMessage

    expect(userMessageInfos.MessageInfo).toBeDefined()
    expect(userMessageInfos.PartyInfo).toBeDefined()
    expect(userMessageInfos.CollaborationInfo).toBeDefined()
    expect(userMessageInfos.MessageProperties).toBeDefined()
    expect(userMessageInfos.PayloadInfo).toBeDefined()
  })

  describe('dans le chemin /Messaging/UserMessage/MessageInfo', () => {
    it('est horodaté', () => {
      horodateur.maintenant = () => '2023-09-01T15:30:00.000Z'
      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur }, { destinataire, ...coins })
      const xml = parseXML(enteteEBMS.enXML())
      const horodatage = xml.Messaging.UserMessage.MessageInfo.Timestamp

      expect(horodatage).toEqual('2023-09-01T15:30:00.000Z')
    })

    it('est identifié', () => {
      process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS = 'oots.eu'
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111'

      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur }, { destinataire, ...coins })
      const xml = parseXML(enteteEBMS.enXML())
      const idMessage = xml.Messaging.UserMessage.MessageInfo.MessageId

      expect(idMessage).toEqual('11111111-1111-1111-1111-111111111111@oots.eu')
    })
  })

  describe('dans le chemin /Messaging/UserMessage/PartyInfo', () => {
    let expediteur
    beforeEach(() => {
      expediteur = new PointAcces(
        process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS,
        process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS,
      )
    })

    afterEach(() => {
      process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS = expediteur.id
      process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS = expediteur.typeId
    })

    it('renseigne l\'expéditeur (C2)', () => {
      process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS = 'unIdentifiant'
      process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS = 'unType'

      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur }, { destinataire, ...coins })
      const xml = parseXML(enteteEBMS.enXML())
      const infosExpediteur = xml.Messaging.UserMessage.PartyInfo.From.PartyId

      expect(infosExpediteur['@_type']).toBe('unType')
      expect(infosExpediteur['#text']).toBe('unIdentifiant')
    })

    it('renseigne le destinataire (C3)', () => {
      const enteteEBMS = new EnteteRequete(
        { adaptateurUUID, horodateur },
        { destinataire: new PointAcces('unIdentifiant', 'unType'), ...coins },
      )
      const xml = parseXML(enteteEBMS.enXML())
      const infosDestinataire = xml.Messaging.UserMessage.PartyInfo.To.PartyId

      expect(infosDestinataire['@_type']).toBe('unType')
      expect(infosDestinataire['#text']).toBe('unIdentifiant')
    })
  })

  describe('dans le chemin /Messaging/UserMessage/MessageProperties', () => {
    it('identifie l\'organisation qui demande le justificatif (C1)', () => {
      const enteteEBMS = new EnteteRequete(
        { adaptateurUUID, horodateur },
        {
          ...coins,
          destinataire,
          emetteurOriginal: { id: '00000000000002', typeId: 'urn:cef.eu:names:identifier:EAS:0009' },
        },
      )
      const xml = parseXML(enteteEBMS.enXML())
      const proprietes = xml.Messaging.UserMessage.MessageProperties.Property
      const expediteur = proprietes.find(p => p['@_name'] === 'originalSender')

      expect(expediteur['@_type']).toEqual('urn:cef.eu:names:identifier:EAS:0009')
      expect(expediteur['#text']).toEqual('00000000000002')
    })

    it('identifie l\'organisation qui détient le justificatif (C4)', () => {
      const enteteEBMS = new EnteteRequete(
        { adaptateurUUID, horodateur },
        {
          ...coins,
          destinataire,
          destinataireFinal: { id: 'DE73524311', typeId: 'urn:cef.eu:names:identifier:EAS:9930' },
        },
      )
      const xml = parseXML(enteteEBMS.enXML())
      const proprietes = xml.Messaging.UserMessage.MessageProperties.Property
      const destinataireFinal = proprietes.find(p => p['@_name'] === 'finalRecipient')

      expect(destinataireFinal['@_type']).toEqual('urn:cef.eu:names:identifier:EAS:9930')
      expect(destinataireFinal['#text']).toEqual('DE73524311')
    })

    it('identifie l\'échange', () => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111'
      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur }, { destinataire, ...coins })
      const xml = parseXML(enteteEBMS.enXML())
      const proprietes = xml.Messaging.UserMessage.MessageProperties.Property

      const idEchange = proprietes.find(p => p['@_name'] === 'ExchangeId')
      expect(idEchange['#text']).toEqual('11111111-1111-1111-1111-111111111111')
    })

    it('reprend l\'identifiant d\'échange fourni plutôt que d\'en générer un', () => {
      const enteteEBMS = new EnteteRequete(
        { adaptateurUUID, horodateur },
        { destinataire, ...coins, idEchange: '22222222-2222-2222-2222-222222222222' },
      )
      const xml = parseXML(enteteEBMS.enXML())
      const proprietes = xml.Messaging.UserMessage.MessageProperties.Property

      const idEchange = proprietes.find(p => p['@_name'] === 'ExchangeId')
      expect(idEchange['#text']).toEqual('22222222-2222-2222-2222-222222222222')
    })

    it('annonce la version du modèle d\'échange', () => {
      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur }, { destinataire, ...coins })
      const xml = parseXML(enteteEBMS.enXML())
      const proprietes = xml.Messaging.UserMessage.MessageProperties.Property

      const version = proprietes.find(p => p['@_name'] === 'SpecificationId')
      expect(version['#text']).toEqual('oots-edm:v2.0')
    })
  })

  describe('dans le chemin /Messaging/UserMessage/PayloadInfo', () => {
    it('identifie le payload du message', () => {
      const enteteEBMS = new EnteteRequete(
        { adaptateurUUID, horodateur },
        { idPayload: 'cid:11111111-1111-1111-1111-111111111111@oots.eu', destinataire, ...coins },
      )
      const xml = parseXML(enteteEBMS.enXML())
      const idPayload = xml.Messaging.UserMessage.PayloadInfo.PartInfo['@_href']

      expect(idPayload).toEqual('cid:11111111-1111-1111-1111-111111111111@oots.eu')
    })
  })
})
