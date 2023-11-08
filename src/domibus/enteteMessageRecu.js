class EnteteMessageRecu {
  constructor(donneesEntete) {
    this.enteteMessageUtilisateur = donneesEntete.Messaging.UserMessage;
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

  idPayload() {
    const infos = [].concat(this.enteteMessageUtilisateur.PayloadInfo.PartInfo);

    const infosPayloadMessageEBMS = infos.find((i) => {
      const proprietes = [].concat(i.PartProperties.Property);
      const proprieteMimeType = proprietes.find((p) => p['@_name'] === 'MimeType');
      return proprieteMimeType['#text'] === 'application/x-ebrs+xml';
    });

    return infosPayloadMessageEBMS['@_href'];
  }
}

module.exports = EnteteMessageRecu;
