const Entete = require('./entete');

class EnteteRequete extends Entete {
  static action() {
    return Entete.EXECUTION_REQUETE;
  }
}

module.exports = EnteteRequete;
