const Entete = require('./entete');

class EnteteReponse extends Entete {
  static action() {
    return Entete.EXECUTION_REPONSE;
  }
}

module.exports = EnteteReponse;
