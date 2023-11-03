const EnteteMessageRecu = require('./enteteMessageRecu');
const ReponseDomibus = require('./reponseDomibus');
const { ErreurReponseRequete } = require('../erreurs');

class ReponseRecuperationMessage extends ReponseDomibus {
  constructor(...args) {
    super(...args);
    this.entete = new EnteteMessageRecu(this.xml.Envelope.Header);
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

    const messageReponseEncode = this.xml.Envelope.Body.retrieveMessageResponse.payload.value;
    const messageReponseDecode = Buffer.from(messageReponseEncode, 'base64').toString('ascii');
    const messageXML = this.parser.parse(messageReponseDecode);

    if (enErreur(messageXML)) {
      const messageErreur = messageXML.QueryResponse.Exception['@_message'];
      throw new ErreurReponseRequete(messageErreur);
    }

    return messageXML.QueryResponse.Exception.Slot
      .find((slot) => slot['@_name'] === 'PreviewLocation').SlotValue.Value;
  }
}

module.exports = ReponseRecuperationMessage;
