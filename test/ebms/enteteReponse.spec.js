const Entete = require('../../src/ebms/entete')
const EnteteReponse = require('../../src/ebms/enteteReponse')
const PointAcces = require('../../src/ebms/pointAcces')
const PieceJointe = require('../../src/ebms/pieceJointe')

describe('L\'entête d\'une réponse', () => {
  const adaptateurUUID = {}
  const horodateur = {}
  const config = { adaptateurUUID, horodateur }
  const destinataire = new PointAcces('unID', 'unTypeID')
  // L'entête refuse une identité de coin absente : ces deux-là la fournissent.
  const coins = {
    emetteurOriginal: { id: '00000000000002', typeId: 'urn:cef.eu:names:identifier:EAS:0009' },
    destinataireFinal: { id: 'DE73524311', typeId: 'urn:cef.eu:names:identifier:EAS:9930' },
  }

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => ''
    horodateur.maintenant = () => ''
  })

  it('connaît son action', () => {
    expect(EnteteReponse.action()).toEqual(Entete.EXECUTION_REPONSE)
  })

  it('ne contient pas de pièce jointe si aucune n\'est fournie', () => {
    const enteteReponse = new EnteteReponse(config, { destinataire, ...coins })

    expect(enteteReponse.enXML()).not.toContain('application/pdf')
  })

  it('peut contenir une pièce jointe', () => {
    const entete = new EnteteReponse(config, {
      pieceJointe: new PieceJointe('unIdentifiantPieceJointe', 'dW50cnVj'),
      destinataire,
      ...coins,
    })

    expect(entete.enXML()).toContain('application/pdf')
    expect(entete.enXML()).toContain('PartInfo href="unIdentifiantPieceJointe"')
  })
})
