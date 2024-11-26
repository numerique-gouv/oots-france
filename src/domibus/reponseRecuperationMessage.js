const EnteteMessageRecu = require('./enteteMessageRecu');
const FabriqueMessages = require('./fabriqueMessages');
const ReponseDomibus = require('./reponseDomibus');

class ReponseRecuperationMessage extends ReponseDomibus {
  constructor(...args) {
    super(...args);
    this.entete = new EnteteMessageRecu(this.xml.Envelope.Header);

    this.idsPayloads = this.entete.payloads();
    const corpsMessageDecode = this.payload('application/x-ebrs+xml').toString();
    const corpsMessageParse = this.parser.parse(corpsMessageDecode);

    this.corpsMessage = FabriqueMessages.nouveauMessage(this.entete.action(), corpsMessageParse);
  }

  action() {
    return this.entete.action();
  }

  codeDemarche() {
    return this.corpsMessage.codeDemarche();
  }

  demandeur() {
    return this.corpsMessage.demandeur();
  }

  expediteur() {
    return this.entete.expediteur();
  }

  idConversation() {
    return this.entete.idConversation();
  }

  idRequete() {
    return this.corpsMessage.idRequete();
  }

  idRequeteur() {
    return this.requeteur().id;
  }

  payload(mimeType) {
    const payloads = [].concat(this.xml.Envelope.Body.retrieveMessageResponse.payload);
    const corpsMessageEncode = payloads
      .find((p) => p['@_payloadId'] === this.idsPayloads[mimeType])
      .value;

    return Buffer.from(corpsMessageEncode, 'base64');
  }

  pieceJustificative() {
    return this.payload('application/pdf');
  }

  reponse(config) {
    return this.corpsMessage.reponse(
      config,
      {
        demandeur: this.demandeur(),
        destinataire: this.expediteur(),
        idConversation: this.idConversation(),
        idRequete: this.idRequete(),
        requeteur: this.requeteur(),
      },
    );
  }

  requeteur() {
    return this.corpsMessage.requeteur();
  }

  suiteConversation() {
    return this.corpsMessage.suiteConversation();
  }
}

module.exports = ReponseRecuperationMessage;
