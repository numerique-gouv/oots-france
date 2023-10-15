const ETAT = {
  DEMARRE: 'démarré',
  ARRETE: 'arrêté',
};

class EcouteurDomibus {
  constructor(config = {}) {
    this.adaptateurDomibus = config.adaptateurDomibus;
    this.intervalleEcoute = config.intervalleEcoute;
    this.etatEcouteur = ETAT.ARRETE;
  }

  arreteEcoute() {
    clearInterval(this.idIntervalle);
    this.etatEcouteur = ETAT.ARRETE;
  }

  ecoute() {
    if (this.estArrete()) {
      this.idIntervalle = setInterval(
        this.adaptateurDomibus.traiteMessageSuivant,
        this.intervalleEcoute,
      );
      this.etatEcouteur = ETAT.DEMARRE;
    }
  }

  estArrete() {
    return this.etatEcouteur === ETAT.ARRETE;
  }

  etat() {
    return this.etatEcouteur;
  }
}

module.exports = EcouteurDomibus;
