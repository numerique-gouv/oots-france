const SessionFCPlus = require('./sessionFCPlus');

class FabriqueSessionFCPlus {
  constructor(config) {
    this.config = config;
    this.adaptateurChiffrement = config.adaptateurChiffrement;
    this.adaptateurFranceConnectPlus = config.adaptateurFranceConnectPlus;
  }

  peupleDonneesJetonAcces(code) {
    const conserveJetonAcces = (jetonAcces) => { this.session.jetonAcces = jetonAcces; };

    const conserveJWT = (jwe) => this.adaptateurChiffrement
      .dechiffreJWE(jwe)
      .then((jwt) => { this.session.jwt = jwt; });

    const conserveURLClefsPubliques = () => this.adaptateurFranceConnectPlus
      .recupereURLClefsPubliques()
      .then((url) => { this.session.urlClefsPubliques = url; });

    return this.adaptateurFranceConnectPlus.recupereDonneesJetonAcces(code)
      .then((donnees) => Promise.all([
        conserveJetonAcces(donnees.access_token),
        conserveJWT(donnees.id_token),
        conserveURLClefsPubliques(),
      ]));
  }

  nouvelleSession(code) {
    this.session = new SessionFCPlus(this.config);
    return this.peupleDonneesJetonAcces(code)
      .then(() => this.session);
  }
}

module.exports = FabriqueSessionFCPlus;
