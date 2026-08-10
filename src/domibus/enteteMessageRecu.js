const PointAcces = require('../ebms/pointAcces')

// Les propriétés ebMS se présentent de la même façon quel que soit leur
// conteneur — `MessageProperties` pour le message, `PartProperties` pour un
// payload : une liste de `Property` distinguées par leur attribut `name`.
// fast-xml-parser rend un objet quand il n'y en a qu'une et un tableau au-delà,
// d'où la coercition.
const valeurPropriete = (sectionProprietes, nom) => [].concat(sectionProprietes?.Property ?? [])
  .find(p => p['@_name'] === nom)
  ?.['#text']

class EnteteMessageRecu {
  constructor(donneesEntete) {
    this.enteteMessageUtilisateur = donneesEntete.Messaging.UserMessage
    this.infosPayloads = [].concat(this.enteteMessageUtilisateur.PayloadInfo.PartInfo)
  }

  action() {
    return this.enteteMessageUtilisateur.CollaborationInfo.Action
  }

  expediteur() {
    const infosExpediteur = this.enteteMessageUtilisateur.PartyInfo.From.PartyId
    return new PointAcces(infosExpediteur['#text'], infosExpediteur['@_type'])
  }

  idConversation() {
    return this.enteteMessageUtilisateur.CollaborationInfo.ConversationId
  }

  idEchange() {
    return valeurPropriete(this.enteteMessageUtilisateur.MessageProperties, 'ExchangeId')
  }

  // L'identifiant que la passerelle donne au message : c'est lui qu'on porte
  // dans la page « Message Log » de la console Domibus pour retrouver, en face
  // d'un événement du journal, l'accusé de réception signé qui lui correspond.
  idMessage() {
    return this.enteteMessageUtilisateur.MessageInfo.MessageId
  }

  payloads() {
    return this.infosPayloads.reduce((acc, infosPayload) => {
      const typeMime = valeurPropriete(infosPayload.PartProperties, 'MimeType')

      return Object.assign(acc, { [typeMime]: infosPayload['@_href'] })
    }, {})
  }
}

module.exports = EnteteMessageRecu
