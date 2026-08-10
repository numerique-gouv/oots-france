const EnteteMessageRecu = require('../../src/domibus/enteteMessageRecu')

describe('Un entête de message Domibus reçu', () => {
  const donnees = {
    Messaging: {
      UserMessage: {
        PayloadInfo: {
          PartInfo: [{
            '@_href': 'cid:11111111-1111-1111-1111-111111111111@regrep.oots.eu',
            'PartProperties': { Property: { '@_name': 'MimeType', '#text': 'application/x-ebrs+xml' } },
          }, {
            '@_href': 'cid:22222222-2222-2222-2222-222222222222@pdf.oots.eu',
            'PartProperties': { Property: { '@_name': 'MimeType', '#text': 'application/pdf' } },
          }],
        },
      },
    },
  }

  const avecProprietesMessage = proprietes => ({
    Messaging: {
      UserMessage: { ...donnees.Messaging.UserMessage, MessageProperties: { Property: proprietes } },
    },
  })

  it('retourne les différents identifiants de payload par type MIME', () => {
    const entete = new EnteteMessageRecu(donnees)
    expect(entete.payloads()).toEqual({
      'application/x-ebrs+xml': 'cid:11111111-1111-1111-1111-111111111111@regrep.oots.eu',
      'application/pdf': 'cid:22222222-2222-2222-2222-222222222222@pdf.oots.eu',
    })
  })

  describe('sur l\'identifiant d\'échange', () => {
    it('le retrouve parmi plusieurs propriétés', () => {
      const entete = new EnteteMessageRecu(avecProprietesMessage([
        { '@_name': 'originalSender', '#text': 'BR_SI_01' },
        { '@_name': 'ExchangeId', '#text': '22222222-2222-2222-2222-222222222222' },
      ]))

      expect(entete.idEchange()).toEqual('22222222-2222-2222-2222-222222222222')
    })

    // fast-xml-parser rend un objet, et non un tableau, quand la propriété est
    // seule de son espèce.
    it('le retrouve quand il est la seule propriété', () => {
      const entete = new EnteteMessageRecu(avecProprietesMessage(
        { '@_name': 'ExchangeId', '#text': '33333333-3333-3333-3333-333333333333' },
      ))

      expect(entete.idEchange()).toEqual('33333333-3333-3333-3333-333333333333')
    })

    it('ne bronche pas quand le message n\'a aucune propriété', () => {
      const entete = new EnteteMessageRecu(donnees)

      expect(entete.idEchange()).toBeUndefined()
    })

    it('ne bronche pas quand la propriété est absente', () => {
      const entete = new EnteteMessageRecu(avecProprietesMessage(
        { '@_name': 'originalSender', '#text': 'BR_SI_01' },
      ))

      expect(entete.idEchange()).toBeUndefined()
    })
  })
})
