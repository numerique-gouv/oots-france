const entete = require('./entete');

class EnteteRequete {
  constructor(config, donnees) {
    this.config = config;
    this.donnees = donnees;
  }

  enXML() {
    return entete(this.config, this.donnees);
  }
}

module.exports = EnteteRequete;
