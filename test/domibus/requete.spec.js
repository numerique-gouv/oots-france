const ConstructeurXMLParseRequeteRecue = require('../constructeurs/constructeurXMLParseRequeteRecue')
const Requete = require('../../src/domibus/requete')
const CodeDemarche = require('../../src/ebms/codeDemarche')
const Fournisseur = require('../../src/ebms/fournisseur')
const ReponseErreur = require('../../src/ebms/reponseErreur')
const { ErreurMessageIllisible } = require('../../src/erreurs')

describe('Une action de requête reçue depuis Domibus', () => {
  const adaptateurUUID = {}
  const horodateur = {}
  const fournisseurFrancais = Fournisseur.francais({ id: '00000000000001', nom: 'Un fournisseur français' })
  const config = { adaptateurUUID, fournisseurFrancais, horodateur }

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => ''
    horodateur.maintenant = () => ''
  })

  it('connaît l\'identifiant de la requête', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecIdRequete('urn:uuid:12345678-1234-1234-1234-1234567890ab')
      .construis()
    const requete = new Requete(xmlParse)

    expect(requete.idRequete()).toBe('urn:uuid:12345678-1234-1234-1234-1234567890ab')
  })

  it('connaît le code de la démarche', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecCodeDemarche('UN_CODE')
      .construis()
    const requete = new Requete(xmlParse)

    expect(requete.codeDemarche()).toBe('UN_CODE')
  })

  it('conserve le schéma d\'identifiant et la langue d\'un requêteur étranger', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecRequeteur({ id: 'DK22233223', nom: 'Denmark University Portal' })
      .construis()
    const [agentER] = xmlParse.QueryRequest.Slot
      .find(s => s['@_name'] === 'EvidenceRequester').SlotValue.Element
    agentER.Agent.Identifier['@_schemeID'] = 'urn:cef.eu:names:identifier:EAS:0096'
    agentER.Agent.Name[0]['@_lang'] = 'EN'

    const { typeId, langue } = new Requete(xmlParse).requeteur()

    expect(typeId).toBe('urn:cef.eu:names:identifier:EAS:0096')
    expect(langue).toBe('EN')
  })

  // Un schéma vide ne désigne aucun répertoire : le prendre pour une absence
  // étiquetterait en français une organisation qui ne l'est pas.
  it('ne prend pas un schéma d\'identifiant vide pour un requêteur français', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecRequeteur({ id: 'DK22233223', nom: 'Denmark University Portal' })
      .construis()
    const [agentER] = xmlParse.QueryRequest.Slot
      .find(s => s['@_name'] === 'EvidenceRequester').SlotValue.Element
    agentER.Agent.Identifier['@_schemeID'] = ''

    expect(new Requete(xmlParse).requeteur().typeId).toBe('')
  })

  it('connaît le requêteur', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecRequeteur({ id: '12345', nom: 'Un requêteur' })
      .construis()
    const requete = new Requete(xmlParse)

    expect(requete.requeteur().id).toBe('12345')
    expect(requete.requeteur().nom).toBe('Un requêteur')
  })

  it('connaît le requêteur, même si identifiant est un nombre', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecRequeteur({ id: 12345 })
      .construis()
    const requete = new Requete(xmlParse)

    expect(requete.requeteur().id).toBe('12345')
  })

  it('connaît le bénéficiaire', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecDemandeur({
        dateNaissance: '1992-10-22',
        identifiantEidas: 'DK/DE/123123123',
        nom: 'Dupont',
        prenom: 'Jean',
      })
      .construis()
    const requete = new Requete(xmlParse)

    const beneficiaire = requete.beneficiaire()
    expect(beneficiaire.dateNaissance).toBe('1992-10-22')
    expect(beneficiaire.identifiantEidas).toBe('DK/DE/123123123')
    expect(beneficiaire.nom).toBe('Dupont')
    expect(beneficiaire.prenom).toBe('Jean')
  })

  it('connaît le type de justificatif demandé', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecTypeJustificatif({
        id: 'abcdef',
        descriptions: { EN: 'Some Evidence Type', FR: 'Un type de justificatif' },
        formatDistribution: 'text/plain',
      })
      .construis()
    const requete = new Requete(xmlParse)

    const typeJustificatif = requete.typeJustificatif()
    expect(typeJustificatif.id).toBe('abcdef')
    expect(typeJustificatif.descriptions).toEqual({ EN: 'Some Evidence Type', FR: 'Un type de justificatif' })
    expect(typeJustificatif.formatDistribution).toBe('text/plain')
  })

  // Le slot est bien là, mais vide de ce qu'on y cherche : sans ces gardes,
  // l'accès à la propriété absente lèverait un `TypeError`, que rien ne
  // distingue d'une défaillance interne. Ce que la requête typée devient
  // ensuite — un `EDM:ERR:0003` renvoyé, ou le silence quand c'est le
  // requêteur qui manque — se décide dans `reponseRecuperationMessage`, qui a
  // ses propres tests pour les deux issues.
  describe('quand un slot est présent mais vide de ce qu\'on y cherche', () => {
    it('refuse une requête sans agent de classification `ER`', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue().sansContenu('AgentRequeteur').construis()

      expect(() => new Requete(xmlParse).requeteur()).toThrow(ErreurMessageIllisible)
    })

    it('refuse une requête sans personne physique', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue().sansContenu('Person').construis()

      expect(() => new Requete(xmlParse).beneficiaire()).toThrow(ErreurMessageIllisible)
    })

    it('refuse une requête sans type de justificatif', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue().sansContenu('DataServiceEvidenceType').construis()

      expect(() => new Requete(xmlParse).typeJustificatif()).toThrow(ErreurMessageIllisible)
    })

    it('refuse une requête sans format de distribution', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue().sansContenu('DistributedAs').construis()

      expect(() => new Requete(xmlParse).typeJustificatif()).toThrow(ErreurMessageIllisible)
    })
  })

  describe('avec comme démarche une demande de bourse', () => {
    it('transmets l\'identifiant de la requête', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis()
      const requete = new Requete(xmlParse)
      const reponse = requete.reponse(config, { idRequete: '12345', requeteur: requete.requeteur() })

      expect(reponse.idRequete).toBe('12345')
    })

    it('répond avec une `ReponseErreur`', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis()
      const requete = new Requete(xmlParse)

      expect(requete.reponse(config, { requeteur: requete.requeteur() })).toBeInstanceOf(ReponseErreur)
    })

    it('répond avec une erreur OBJECT_NOT_FOUND', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis()
      const requete = new Requete(xmlParse)
      const reponseErreur = requete.reponse(config, { requeteur: requete.requeteur() })

      expect(reponseErreur.codeException).toBe('EDM:ERR:0004')
    })

    it('ne joint pas de pièce justificative', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis()
      const requete = new Requete(xmlParse)
      const reponseErreur = requete.reponse(config, { requeteur: requete.requeteur() })

      expect(reponseErreur.pieceJointePresente()).toBe(false)
    })
  })

  describe('avec comme démarche une vérification système', () => {
    it('répond avec un message de vérification système avec pièce jointe', () => {
      adaptateurUUID.genereUUID = () => '12345678-1234-1234-1234-1234567890ab'
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .construis()
      const requete = new Requete(xmlParse)
      const reponse = requete.reponse(config, {
        requeteur: requete.requeteur(),
        typeJustificatif: requete.typeJustificatif(),
      })

      expect(reponse.pieceJointePresente()).toBe(true)
    })

    it('répond avec une erreur UNSUPPORTED_CAPABILITY quand le format demandé n\'est pas le PDF', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .avecTypeJustificatif({ formatDistribution: 'application/xml' })
        .construis()
      const requete = new Requete(xmlParse)
      const reponseErreur = requete.reponse(config, {
        requeteur: requete.requeteur(),
        typeJustificatif: requete.typeJustificatif(),
      })

      expect(reponseErreur).toBeInstanceOf(ReponseErreur)
      expect(reponseErreur.codeException).toBe('EDM:ERR:0007')
    })
  })
})
