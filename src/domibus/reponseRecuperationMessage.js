const EnteteMessageRecu = require('./enteteMessageRecu');
const ReponseDomibus = require('./reponseDomibus');
const { ErreurReponseRequete } = require('../erreurs');

class ReponseRecuperationMessage extends ReponseDomibus {
  constructor(...args) {
    super(...args);
    this.entete = new EnteteMessageRecu(this.xml.Envelope.Header);

    this.idPayload = this.entete.idPayload();

    const payloads = [].concat(this.xml.Envelope.Body.retrieveMessageResponse.payload);
    const messageReponseEncode = payloads
      .find((p) => p['@_payloadId'] === this.idPayload)
      .value;
    const messageReponseDecode = Buffer.from(messageReponseEncode, 'base64').toString('ascii');
    this.messageEBMSParse = this.parser.parse(messageReponseDecode);
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

  urlRedirection() {
    const enErreur = (xml) => xml.QueryResponse['@_status'] === 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure'
      && xml.QueryResponse.Exception['@_type'] !== 'rs:AuthorizationExceptionType';

    if (enErreur(this.messageEBMSParse)) {
      const messageErreur = this.messageEBMSParse.QueryResponse.Exception['@_message'];
      throw new ErreurReponseRequete(messageErreur);
    }

    return this.messageEBMSParse.QueryResponse.Exception.Slot
      .find((slot) => slot['@_name'] === 'PreviewLocation').SlotValue.Value;
  }
}

module.exports = ReponseRecuperationMessage;
