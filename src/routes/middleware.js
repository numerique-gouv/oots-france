class Middleware {
  constructor(config) {
    this.adaptateurChiffrement = config.adaptateurChiffrement;
    this.adaptateurEnvironnement = config.adaptateurEnvironnement;
  }

  renseigneUtilisateurCourant(requete, _reponse, suite) {
    const secret = this.adaptateurEnvironnement.secretJetonSession();
    return this.adaptateurChiffrement.verifieJeton(requete.session.jeton, secret)
      .then((infosUtilisateur) => { requete.utilisateurCourant = infosUtilisateur; })
      .catch(() => { requete.utilisateurCourant = undefined; })
      .then(() => suite());
  }
}

module.exports = Middleware;
