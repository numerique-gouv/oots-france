const Entete = require('./entete');

class EnteteErreur extends Entete {
  static action() {
    return Entete.REPONSE_ERREUR;
  }
}

module.exports = EnteteErreur;
