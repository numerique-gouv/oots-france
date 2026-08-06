const PointAcces = require('./pointAcces')
const PieceJointeVide = require('./pieceJointeVide')
const { IDENTIFIANT_SPECIFICATION_EDM } = require('./specificationEdm')
const { echappeXML } = require('./echappement')
const { identiteEbms } = require('./identiteEbms')

const ACTIONS = {
  EXECUTION_REQUETE: 'ExecuteQueryRequest',
  EXECUTION_REPONSE: 'ExecuteQueryResponse',
  REPONSE_ERREUR: 'ExceptionResponse',
}

class Entete {
  constructor(config = {}, donnees = {}) {
    this.expediteur = PointAcces.expediteur()

    this.horodateur = config.horodateur
    this.destinataire = donnees.destinataire
    this.idConversation = donnees.idConversation
    this.idPayload = donnees.idPayload
    this.pieceJointe = donnees.pieceJointe || new PieceJointeVide()

    // Identités des coins C1 et C4, qui s'inversent selon le sens du message :
    // chaque message les calcule à partir du requêteur et du fournisseur. Un
    // coin non renseigné est refusé ici plutôt qu'annoncé `undefined` sur le
    // réseau — voir `identiteEbms`.
    this.emetteurOriginal = identiteEbms(donnees.emetteurOriginal ?? {}, 'L\'émetteur d\'origine (C1)')
    this.destinataireFinal = identiteEbms(donnees.destinataireFinal ?? {}, 'Le destinataire final (C4)')

    const { adaptateurUUID } = config
    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS
    this.idMessage = `${adaptateurUUID.genereUUID()}@${suffixe}`

    // L'échange couvre la requête et les réponses qui lui succèdent : le
    // fournisseur reprend l'identifiant reçu au lieu d'en générer un nouveau.
    this.idEchange = donnees.idEchange || adaptateurUUID.genereUUID()
  }

  static action() {
    throw new Error('Méthode non implémentée dans classe abstraite')
  }

  enXML() {
    const horodatage = this.horodateur.maintenant()
    const baliseIdConversation = (typeof this.idConversation !== 'undefined')
      ? `<eb:ConversationId>${echappeXML(this.idConversation)}</eb:ConversationId>`
      : ''

    return `
<eb:Messaging xmlns:eb="http://docs.oasis-open.org/ebxml-msg/ebms/v3.0/ns/core/200704/">
  <eb:UserMessage>
    <eb:MessageInfo>
      <eb:Timestamp>${horodatage}</eb:Timestamp>
      <eb:MessageId>${echappeXML(this.idMessage)}</eb:MessageId>
    </eb:MessageInfo>
    <eb:PartyInfo>
      <eb:From>${this.expediteur.enXML()}</eb:From>
      <eb:To>${this.destinataire.enXML()}</eb:To>
    </eb:PartyInfo>
    <eb:CollaborationInfo>
      <eb:Service type="urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0">QueryManager</eb:Service>
      <eb:Action>${this.constructor.action()}</eb:Action>
      ${baliseIdConversation}
    </eb:CollaborationInfo>
    <eb:MessageProperties>
      <eb:Property name="originalSender" type="${echappeXML(this.emetteurOriginal.typeId)}">${echappeXML(this.emetteurOriginal.id)}</eb:Property>
      <eb:Property name="finalRecipient" type="${echappeXML(this.destinataireFinal.typeId)}">${echappeXML(this.destinataireFinal.id)}</eb:Property>
      <eb:Property name="ExchangeId">${echappeXML(this.idEchange)}</eb:Property>
      <eb:Property name="SpecificationId">${IDENTIFIANT_SPECIFICATION_EDM}</eb:Property>
    </eb:MessageProperties>
    <eb:PayloadInfo>
      <eb:PartInfo href="${echappeXML(this.idPayload)}">
        <eb:PartProperties>
          <eb:Property name="MimeType">application/x-ebrs+xml</eb:Property>
        </eb:PartProperties>
      </eb:PartInfo>
      ${this.pieceJointe.enXMLDansEntete()}
    </eb:PayloadInfo>
  </eb:UserMessage>
</eb:Messaging>
    `
  }
}

Object.assign(Entete, ACTIONS)

module.exports = Entete
