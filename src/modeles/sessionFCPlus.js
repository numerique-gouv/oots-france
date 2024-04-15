const { ErreurEchecAuthentification } = require('../erreurs');

const leveErreurParametreManquant = (messageParamManquant) => (
  `${messageParamManquant}. La session a-t-elle bien été instanciée depuis la fabrique ?`
);

class SessionFCPlus {
  constructor(config) {
    this.adaptateurChiffrement = config.adaptateurChiffrement;
    this.adaptateurFranceConnectPlus = config.adaptateurFranceConnectPlus;

    this.jetonAcces = undefined;
    this.jwt = undefined;
    this.urlClefsPubliques = undefined;
  }

  enJSON() {
    if (!this.jwt) {
      return Promise.reject(new Error(leveErreurParametreManquant('JWT non défini')));
    }

    if (!this.urlClefsPubliques) {
      return Promise.reject(new Error(leveErreurParametreManquant('URL clefs publiques non définie')));
    }

    return this.infosUtilisateurDechiffrees()
      .then((jwtInfosUtilisateur) => this.adaptateurChiffrement.verifieSignatureJWTDepuisJWKS(
        jwtInfosUtilisateur,
        this.urlClefsPubliques,
      ))
      .then((infosDechiffrees) => Object.assign(infosDechiffrees, { jwtSessionFCPlus: this.jwt }))
      .catch((e) => Promise.reject(new ErreurEchecAuthentification(e.message)));
  }

  infosUtilisateurDechiffrees() {
    if (!this.jetonAcces) {
      return Promise.reject(new Error(leveErreurParametreManquant('Jeton accès non défini')));
    }

    return this.adaptateurFranceConnectPlus.recupereInfosUtilisateurChiffrees(this.jetonAcces)
      .then((jwe) => this.adaptateurChiffrement.dechiffreJWE(jwe));
  }
}

module.exports = SessionFCPlus;
