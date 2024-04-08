class SessionFCPlus {
  constructor(donnees) {
    this.jetonAcces = donnees?.jetonAcces;
    this.jwt = donnees?.jwt;
    this.infosUtilisateurChiffrees = undefined;
  }

  avecInfosUtilisateurChiffrees(infos) {
    this.infosUtilisateurChiffrees = infos;
    return this;
  }
}

module.exports = SessionFCPlus;
