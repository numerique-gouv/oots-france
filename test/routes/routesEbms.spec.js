const axios = require('axios')

const serveurTest = require('./serveurTest')
const leveErreur = require('./utils')
const { parseXML } = require('../../src/ebms/utils')

const proprietesMessage = xml => [].concat(
  parseXML(xml).Messaging.UserMessage.MessageProperties.Property,
)

// `#text` est absent quand la valeur manque : le lire tel quel ferait passer
// une propriété vide pour une propriété correcte. Un identifiant tout en
// chiffres revient en nombre du parseur, d'où la conversion — la même que fait
// `MessageRecu.idRequeteur` en production.
const proprieteNommee = (proprietes, nom) => {
  const propriete = proprietes.find(p => p['@_name'] === nom)
  return { type: propriete['@_type'], valeur: propriete['#text']?.toString() }
}

describe('Le serveur des routes `/ebms`', () => {
  const serveur = serveurTest()
  let port

  beforeEach(suite => serveur.initialise(() => {
    port = serveur.port()
    suite()
  }))

  afterEach(suite => serveur.arrete(suite))

  describe('sur GET /ebms/entetes/requeteJustificatif', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/entetes/requeteJustificatif`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8')
      })
      .catch(leveErreur))

    it('génère un identifiant unique de conversation', () => {
      serveur.adaptateurUUID().genereUUID = () => '11111111-1111-1111-1111-111111111111'

      return axios.get(`http://localhost:${port}/ebms/entetes/requeteJustificatif`)
        .then((reponse) => {
          const xml = parseXML(reponse.data)
          const idConversation = xml.Messaging.UserMessage.CollaborationInfo.ConversationId
          expect(idConversation).toEqual('11111111-1111-1111-1111-111111111111')
        })
        .catch(leveErreur)
    })

    it('identifie les coins C1 et C4', () => axios.get(`http://localhost:${port}/ebms/entetes/requeteJustificatif`)
      .then((reponse) => {
        const proprietes = proprietesMessage(reponse.data)

        expect(proprieteNommee(proprietes, 'originalSender')).toEqual({
          type: 'urn:cef.eu:names:identifier:EAS:0009', valeur: '00000000000002',
        })
        expect(proprieteNommee(proprietes, 'finalRecipient')).toEqual({
          type: 'urn:cef.eu:names:identifier:EAS:0009', valeur: '00000000000001',
        })
      })
      .catch(leveErreur))
  })

  describe('sur GET /ebms/entetes/reponseErreur', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/entetes/reponseErreur`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8')
      })
      .catch(leveErreur))

    it('identifie les coins, inversés par rapport à la requête', () => axios.get(`http://localhost:${port}/ebms/entetes/reponseErreur`)
      .then((reponse) => {
        const proprietes = proprietesMessage(reponse.data)

        expect(proprieteNommee(proprietes, 'originalSender').valeur).toEqual('00000000000001')
        expect(proprieteNommee(proprietes, 'finalRecipient').valeur).toEqual('00000000000002')
      })
      .catch(leveErreur))
  })

  describe('sur GET /ebms/messages/requeteJustificatif', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/messages/requeteJustificatif`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8')
      })
      .catch(leveErreur))

    it('génère un identifiant unique de requête', () => {
      serveur.adaptateurUUID().genereUUID = () => '11111111-1111-1111-1111-111111111111'

      return axios.get(`http://localhost:${port}/ebms/messages/requeteJustificatif`)
        .then((reponse) => {
          const xml = parseXML(reponse.data)
          const requestId = xml.QueryRequest['@_id']
          expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111')
        })
        .catch(leveErreur)
    })
  })

  describe('sur GET /ebms/messages/reponseErreur', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/messages/reponseErreur`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8')
      })
      .catch(leveErreur))
  })

  describe('sur GET /ebms/messages/reponseJustificatif', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/messages/reponseJustificatif`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8')
      })
      .catch(leveErreur))
  })
})
