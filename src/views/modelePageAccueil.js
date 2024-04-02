const fs = require('node:fs');

class ModelePageAccueil {
  infosUtilisateur;

  constructor(infosUtilisateur, modeleVierge) {
    this.infosUtilisateur = infosUtilisateur;
    this.modeleVierge = modeleVierge || fs.readFileSync(`${__dirname}/pageAccueil.html`).toString();
  }

  enHTML = () => (this.infosUtilisateur
    ? this.avecUtilisateurConnecte()
    : this.sansUtilisateurConnecte());

  avecUtilisateurConnecte() {
    return this.modeleVierge.replace(
      '{{contenu}}',
      `Utilisateur courant : ${this.infosUtilisateur.given_name} ${this.infosUtilisateur.family_name}`,
    );
  }

  sansUtilisateurConnecte() {
    return this.modeleVierge.replace(
      '{{contenu}}',
      'Pas d\'utilisateur courant',
    );
  }
}

module.exports = ModelePageAccueil;
