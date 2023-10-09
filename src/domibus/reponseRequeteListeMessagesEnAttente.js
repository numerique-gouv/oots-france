const ReponseDomibus = require('./reponseDomibus');

class ReponseRequeteListeMessagesEnAttente extends ReponseDomibus {
  idMessageSuivant() {
    const resultat = this.xml['soap:Envelope']['soap:Body']['ns4:listPendingMessagesResponse'].messageID;
    return (typeof resultat === 'string') ? resultat : resultat?.[0];
  }

  messageEnAttente() {
    return !!this.idMessageSuivant();
  }
}

module.exports = ReponseRequeteListeMessagesEnAttente;
