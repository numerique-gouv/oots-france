const EnteteMessageRecu = require('./enteteMessageRecu');
const ReponseDomibus = require('./reponseDomibus');
const { ErreurReponseRequete } = require('../erreurs');

class ReponseRecuperationMessage extends ReponseDomibus {
  constructor(...args) {
    super(...args);
    this.entete = new EnteteMessageRecu(this.xml['soap:Envelope']['soap:Header']);
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
    const enErreur = (xml) => xml['query:QueryResponse']['@_status'] === 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure'
      && xml['query:QueryResponse']['rs:Exception']['@_xsi:type'] !== 'rs:AuthorizationExceptionType';

    const messageReponseEncode = this.xml['soap:Envelope']['soap:Body']['ns4:retrieveMessageResponse'].payload.value;
    const messageReponseDecode = Buffer.from(messageReponseEncode, 'base64').toString('ascii');
    const messageXML = this.parser.parse(messageReponseDecode);

    if (enErreur(messageXML)) {
      const messageErreur = messageXML['query:QueryResponse']['rs:Exception']['@_message'];
      throw new ErreurReponseRequete(messageErreur);
    }

    return messageXML['query:QueryResponse']['rs:Exception']['rim:Slot']
      .find((slot) => slot['@_name'] === 'PreviewLocation')['rim:SlotValue']['rim:Value'];
  }
}

module.exports = ReponseRecuperationMessage;
