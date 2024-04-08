const { ErreurEchecAuthentification } = require('../erreurs');

class SessionFCPlus {
  constructor(config, code) {
    this.adaptateurChiffrement = config.adaptateurChiffrement;
    this.adaptateurFranceConnectPlus = config.adaptateurFranceConnectPlus;
    this.code = code;

    this.jetonAcces = undefined;
    this.jwt = undefined;
    this.urlClefsPubliques = undefined;
  }

  conserveJetonAcces(jetonAcces) {
    this.jetonAcces = jetonAcces;
  }

  conserveJWT(jwe) {
    return this.adaptateurChiffrement.dechiffreJWE(jwe)
      .then((jwt) => { this.jwt = jwt; });
  }

  conserveURLClefsPubliques() {
    return this.adaptateurFranceConnectPlus.recupereURLClefsPubliques()
      .then((url) => { this.urlClefsPubliques = url; });
  }

  enJSON() {
    return this.peupleDonneesJetonAcces()
      .then(() => this.infosUtilisateurDechiffrees())
      .then((jwtInfosUtilisateur) => this.adaptateurChiffrement.verifieSignatureJWTDepuisJWKS(
        jwtInfosUtilisateur,
        this.urlClefsPubliques,
      ))
      .then((infosDechiffrees) => Object.assign(infosDechiffrees, { jwtSessionFCPlus: this.jwt }))
      .catch((e) => Promise.reject(new ErreurEchecAuthentification(e.message)));
  }

  infosUtilisateurDechiffrees() {
    return this.adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees(this.jetonAcces)
      .then((jwe) => this.adaptateurChiffrement.dechiffreJWE(jwe));
  }

  peupleDonneesJetonAcces() {
    return this.adaptateurFranceConnectPlus.recupereDonneesJetonAcces(this.code)
      .then((donnees) => Promise.all([
        this.conserveJetonAcces(donnees.access_token),
        this.conserveJWT(donnees.id_token),
        this.conserveURLClefsPubliques(),
      ]));
  }
}

module.exports = SessionFCPlus;
