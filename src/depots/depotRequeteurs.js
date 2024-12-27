const { ErreurRequeteurInexistant } = require('../erreurs');
const adaptateurChiffrement = require('../adaptateurs/adaptateurChiffrement');
const adaptateurEnvironnement = require('../adaptateurs/adaptateurEnvironnement');
const Requeteur = require('../ebms/requeteur');

class DepotRequeteurs {
  constructor(donnees) {
    this.donnees = donnees || adaptateurEnvironnement.donneesRequeteurs();
  }

  trouveRequeteur(id) {
    const donneesRequeteur = this.donnees[id];
    if (typeof donneesRequeteur === 'undefined') {
      return Promise.reject(
        new ErreurRequeteurInexistant(`Le requêteur avec comme identifiant "${id}" est inexistant`),
      );
    }

    const resultat = new Requeteur({ adaptateurChiffrement }, { id, ...donneesRequeteur });
    return Promise.resolve(resultat);
  }
}

module.exports = DepotRequeteurs;
