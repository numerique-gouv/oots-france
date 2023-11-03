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
}

module.exports = EnteteMessageRecu;
