const ReponseDomibus = require('./reponseDomibus');

class ReponseRequeteListeMessagesEnAttente extends ReponseDomibus {
  idMessageSuivant() {
    const resultat = this.xml.Envelope.Body.listPendingMessagesResponse.messageID;
    return (typeof resultat === 'string') ? resultat : resultat?.[0];
  }

  messageEnAttente() {
    return !!this.idMessageSuivant();
  }
}

module.exports = ReponseRequeteListeMessagesEnAttente;
