class EnteteMessageRecu {
  constructor(donneesEntete) {
    this.enteteMessageUtilisateur = donneesEntete.Messaging.UserMessage;
    this.infosPayloads = [].concat(this.enteteMessageUtilisateur.PayloadInfo.PartInfo);
  }

  action() {
    return this.enteteMessageUtilisateur.CollaborationInfo.Action;
  }

  expediteur() {
    return this.enteteMessageUtilisateur.PartyInfo.From.PartyId['#text'];
  }

  idConversation() {
    return this.enteteMessageUtilisateur.CollaborationInfo.ConversationId;
  }

  idMessage() {
    return this.enteteMessageUtilisateur.MessageInfo.MessageId;
  }

  idPayload(typeMime) {
    const infosPayloadMessageEBMS = this.infosPayloads.find((i) => {
      const proprietes = [].concat(i.PartProperties.Property);
      const proprieteMimeType = proprietes.find((p) => p['@_name'] === 'MimeType');
      return proprieteMimeType['#text'] === typeMime;
    });

    return infosPayloadMessageEBMS['@_href'];
  }

  payloads() {
    return this.infosPayloads.reduce((acc, infosPayload) => {
      const proprietes = [].concat(infosPayload.PartProperties.Property);
      const proprieteTypeMime = proprietes.find((p) => p['@_name'] === 'MimeType');
      const typeMime = proprieteTypeMime['#text'];

      return Object.assign(acc, { [typeMime]: infosPayload['@_href'] });
    }, {});
  }
}

module.exports = EnteteMessageRecu;
