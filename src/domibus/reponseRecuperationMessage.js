const ReponseDomibus = require('./reponseDomibus');

class ReponseRecuperationMessage extends ReponseDomibus {
  action() {
    return this.xml['soap:Envelope']['soap:Header']['ns5:Messaging']['ns5:UserMessage']['ns5:CollaborationInfo']['ns5:Action'];
  }

  idConversation() {
    return this.xml['soap:Envelope']['soap:Header']['ns5:Messaging']['ns5:UserMessage']['ns5:CollaborationInfo']['ns5:ConversationId'];
  }

  urlRedirection() {
    const messageReponseEncode = this.xml['soap:Envelope']['soap:Body']['ns4:retrieveMessageResponse'].payload.value;
    const messageReponseDecode = Buffer.from(messageReponseEncode, 'base64').toString('ascii');

    return this.parser.parse(messageReponseDecode)['query:QueryResponse']['rs:Exception']['rim:Slot']
      .find((slot) => slot['@_name'] === 'PreviewLocation')['rim:SlotValue']['rim:Value'];
  }
}

module.exports = ReponseRecuperationMessage;
