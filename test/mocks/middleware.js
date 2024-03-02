class MiddlewareFantaisie {
  constructor(donnees) {
    this.reinitialise(donnees);
  }

  reinitialise({ utilisateurCourant }) {
    this.utilisateurCourant = utilisateurCourant;
  }

  renseigneUtilisateurCourant(requete, _reponse, suite) {
    requete.utilisateurCourant = this.utilisateurCourant;
    suite();
  }
}

module.exports = MiddlewareFantaisie;
