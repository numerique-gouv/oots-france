const EnteteMessageRecu = require('./enteteMessageRecu');
const FabriqueMessages = require('./fabriqueMessages');
const ReponseDomibus = require('./reponseDomibus');

class ReponseRecuperationMessage extends ReponseDomibus {
  constructor(...args) {
    super(...args);
    this.entete = new EnteteMessageRecu(this.xml.Envelope.Header);

    this.idPayload = this.entete.idPayload();

    const payloads = [].concat(this.xml.Envelope.Body.retrieveMessageResponse.payload);
    const corpsMessageEncode = payloads
      .find((p) => p['@_payloadId'] === this.idPayload)
      .value;
    const corpsMessageDecode = Buffer.from(corpsMessageEncode, 'base64').toString('ascii');
    const corpsMessageParse = this.parser.parse(corpsMessageDecode);

    this.corpsMessage = FabriqueMessages.nouveauMessage(this.entete.action(), corpsMessageParse);
  }

  action() {
    return this.entete.action();
  }

  expediteur() {
    return this.entete.expediteur();
  }

  idConversation() {
    return this.entete.idConversation();
  }

  idMessage() {
    return this.entete.idMessage();
  }

  suiteConversation() {
    return this.corpsMessage.suiteConversation();
  }
}

module.exports = ReponseRecuperationMessage;
