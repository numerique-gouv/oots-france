class EnteteMessageRecu {
  constructor(donneesEntete) {
    this.enteteMessageUtilisateur = donneesEntete['ns5:Messaging']['ns5:UserMessage'];
  }

  action() {
    return this.enteteMessageUtilisateur['ns5:CollaborationInfo']['ns5:Action'];
  }

  expediteur() {
    return this.enteteMessageUtilisateur['ns5:PartyInfo']['ns5:From']['ns5:PartyId']['#text'];
  }

  idConversation() {
    return this.enteteMessageUtilisateur['ns5:CollaborationInfo']['ns5:ConversationId'];
  }

  idMessage() {
    return this.enteteMessageUtilisateur['ns5:MessageInfo']['ns5:MessageId'];
  }
}

module.exports = EnteteMessageRecu;
