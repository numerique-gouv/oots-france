const ReponseDomibus = require('./reponseDomibus');
const { ErreurReponseRequete } = require('../erreurs');

class ReponseRecuperationMessage extends ReponseDomibus {
  constructor(...args) {
    super(...args);
    this.enteteInfosMessage = this.xml['soap:Envelope']['soap:Header']['ns5:Messaging']['ns5:UserMessage'];
  }

  action() {
    return this.enteteInfosMessage['ns5:CollaborationInfo']['ns5:Action'];
  }

  expediteur() {
    return this.enteteInfosMessage['ns5:PartyInfo']['ns5:From']['ns5:PartyId']['#text'];
  }

  idConversation() {
    return this.enteteInfosMessage['ns5:CollaborationInfo']['ns5:ConversationId'];
  }

  idMessage() {
    return this.enteteInfosMessage['ns5:MessageInfo']['ns5:MessageId'];
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
