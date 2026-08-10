const ConstructeurEnveloppeSOAPAvecPieceJointe = require('../constructeurs/constructeurEnveloppeSOAPAvecPieceJointe')
const ConstructeurEnveloppeSOAPException = require('../constructeurs/constructeurEnveloppeSOAPException')
const ConstructeurEnveloppeSOAPRequete = require('../constructeurs/constructeurEnveloppeSOAPRequete')
const depotJournalFactice = require('../constructeurs/depotJournalFactice')
const journaliseMessageRecu = require('../../src/domibus/journaliseMessageRecu')
const ReponseRecuperationMessage = require('../../src/domibus/reponseRecuperationMessage')
const Fournisseur = require('../../src/ebms/fournisseur')

// Portés en dur par les constructeurs d'enveloppes, qui n'offrent pas de quoi
// les changer : les reprendre ici évite d'élargir ces constructeurs partagés
// pour le seul confort de ces tests.
const ID_CONVERSATION_FIXTURE = '5fe50e16-d6b8-4005-b5ec-0ab097f34448'
const ID_MESSAGE_FIXTURE = '7612ae3c-954d-4fc2-8031-efd139b1248a@resp.gov.si'

describe('La journalisation d\'un message reçu', () => {
  const fournisseurFrancais = Fournisseur.francais({ id: '00000000000001', nom: 'Un fournisseur français' })
  const adaptateurChiffrement = { empreinteSha256: () => 'uneEmpreinte' }

  let depotJournal

  const config = () => ({
    adaptateurChiffrement,
    depotJournal,
    fournisseurFrancais,
  })

  beforeEach(() => {
    depotJournal = depotJournalFactice()
  })

  it('consigne une requête entrante avec ce que la passerelle ignore', () => {
    const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
      .avecIdRequete('urn:uuid:uneRequete')
      .avecCodeDemarche('T1')
      .avecRequeteur({ id: '12345678901234', nom: 'Un requêteur' })
      .construis()
    const message = new ReponseRecuperationMessage(enveloppeSOAP)

    return journaliseMessageRecu(message, config())
      .then(() => {
        const [evenement] = depotJournal.evenementsDeType('requete_recue')

        expect(evenement.actionEbms).toBe('ExecuteQueryRequest')
        expect(evenement.idConversation).toBe(ID_CONVERSATION_FIXTURE)
        expect(evenement.idMessage).toBe(ID_MESSAGE_FIXTURE)
        expect(evenement.idRequete).toBe('urn:uuid:uneRequete')
        expect(evenement.codeDemarche).toBe('T1')
        expect(evenement.autoriteRequerante).toBe('12345678901234')
        expect(evenement.autoriteFournisseuse).toBe('00000000000001')
        expect(evenement.sujetJustificatif).toBeDefined()
      })
  })

  it('consigne une erreur reçue avec son code EDM', () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecIdConversation('uneConversation')
      .avecIdMessage('unMessage@oots.eu')
      .construis()
    const message = new ReponseRecuperationMessage(enveloppeSOAP)

    return journaliseMessageRecu(message, config())
      .then(() => {
        const [evenement] = depotJournal.evenementsDeType('erreur_recue')

        expect(evenement.actionEbms).toBe('ExceptionResponse')
        expect(evenement.idConversation).toBe('uneConversation')
        expect(evenement.codeErreur).toBe('EDM:ERR:0002')
      })
  })

  it('consigne l\'empreinte du justificatif reçu, jamais le justificatif', () => {
    const enveloppeSOAP = new ConstructeurEnveloppeSOAPAvecPieceJointe()
      .avecPieceJointe('cid:unePiece@oots.eu', 'application/pdf', 'Un diplôme')
      .construis()
    const message = new ReponseRecuperationMessage(enveloppeSOAP)

    return journaliseMessageRecu(message, { ...config(), adaptateurChiffrement: { empreinteSha256: contenu => `empreinte de ${contenu}` } })
      .then(() => {
        const [evenement] = depotJournal.evenementsDeType('reponse_recue')

        expect(evenement.actionEbms).toBe('ExecuteQueryResponse')
        expect(evenement.typeMime).toBe('application/pdf')
        expect(evenement.empreinteJustificatif).toBe('empreinte de Un diplôme')
        expect(Object.values(evenement)).not.toContain('Un diplôme')
      })
  })
})
