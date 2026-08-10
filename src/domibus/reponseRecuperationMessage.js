const EnteteMessageRecu = require('./enteteMessageRecu')
const FabriqueMessages = require('./fabriqueMessages')
const ReponseDomibus = require('./reponseDomibus')
const { parseXML } = require('../ebms/utils')

class ReponseRecuperationMessage extends ReponseDomibus {
  constructor(...args) {
    super(...args)
    this.entete = new EnteteMessageRecu(this.xml.Envelope.Header)

    this.idsPayloads = this.entete.payloads()
    const corpsMessageDecode = this.payload('application/x-ebrs+xml').toString()
    const corpsMessageParse = parseXML(corpsMessageDecode)

    this.corpsMessage = FabriqueMessages.nouveauMessage(this.entete.action(), corpsMessageParse)
  }

  action() {
    return this.entete.action()
  }

  codeDemarche() {
    return this.corpsMessage.codeDemarche()
  }

  beneficiaire() {
    return this.corpsMessage.beneficiaire()
  }

  codeErreur() {
    return this.corpsMessage.codeErreur()
  }

  expediteur() {
    return this.entete.expediteur()
  }

  idConversation() {
    return this.entete.idConversation()
  }

  idEchange() {
    return this.entete.idEchange()
  }

  idMessage() {
    return this.entete.idMessage()
  }

  idRequete() {
    return this.corpsMessage.idRequete()
  }

  idRequeteur() {
    return this.requeteur().id
  }

  payload(mimeType) {
    const payloads = [].concat(this.xml.Envelope.Body.retrieveMessageResponse.payload)
    const corpsMessageEncode = payloads
      .find(p => p['@_payloadId'] === this.idsPayloads[mimeType])
      .value

    return Buffer.from(corpsMessageEncode, 'base64')
  }

  // Toutes les réponses n'en portent pas — une erreur, une vérification de
  // système n'ont rien à joindre. Le demander avant d'appeler
  // `pieceJustificative` évite de casser le cycle de sondage sur un message
  // parfaitement valide.
  aUnJustificatif() {
    return typeof this.idsPayloads['application/pdf'] !== 'undefined'
  }

  pieceJustificative() {
    return this.payload('application/pdf')
  }

  reponse(config) {
    return this.corpsMessage.reponse(
      config,
      {
        beneficiaire: this.beneficiaire(),
        destinataire: this.expediteur(),
        idConversation: this.idConversation(),
        idEchange: this.entete.idEchange(),
        idRequete: this.idRequete(),
        requeteur: this.requeteur(),
        typeJustificatif: this.typeJustificatif(),
      },
    )
  }

  requeteur() {
    return this.corpsMessage.requeteur()
  }

  suiteConversation() {
    return this.corpsMessage.suiteConversation()
  }

  typeJustificatif() {
    return this.corpsMessage.typeJustificatif()
  }
}

module.exports = ReponseRecuperationMessage
