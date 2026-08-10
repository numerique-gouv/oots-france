const EnteteMessageRecu = require('./enteteMessageRecu')
const FabriqueMessages = require('./fabriqueMessages')
const ReponseDomibus = require('./reponseDomibus')
const ReponseErreur = require('../ebms/reponseErreur')
const { ErreurMessageIllisible } = require('../erreurs')
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
    // Lus d'abord : ce sont ceux dont la réponse a besoin quoi qu'il arrive,
    // pour être adressée et rattachée à sa conversation. Les quatre premiers
    // viennent de l'entête ebMS ou d'un attribut, et ne peuvent pas manquer
    // sans que le message soit inexploitable de bout en bout ; le requêteur,
    // lui, vient d'un slot. S'il est illisible, l'erreur part d'ici sans être
    // rattrapée : une réponse sans destinataire final n'irait nulle part.
    const donneesCommunes = {
      destinataire: this.expediteur(),
      idConversation: this.idConversation(),
      idEchange: this.entete.idEchange(),
      idRequete: this.idRequete(),
      requeteur: this.requeteur(),
    }

    try {
      return this.corpsMessage.reponse(
        config,
        {
          ...donneesCommunes,
          beneficiaire: this.beneficiaire(),
          typeJustificatif: this.typeJustificatif(),
        },
      )
    }
    catch (e) {
      if (!(e instanceof ErreurMessageIllisible)) throw e

      // Une requête qu'on ne sait pas lire se répond : les TDD réservent
      // `EDM:ERR:0003` à ce cas, et la laisser sans réponse abandonnerait le
      // correspondant au silence.
      return new ReponseErreur(config, {
        ...donneesCommunes,
        exception: ReponseErreur.INVALID_REQUEST_EXCEPTION,
      })
    }
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
