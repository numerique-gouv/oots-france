const fs = require('node:fs');

class ModelePageAccueil {
  infosUtilisateur;

  constructor(infosUtilisateur) {
    this.infosUtilisateur = infosUtilisateur;
    this.modeleVierge = fs.readFileSync(`${__dirname}/pageAccueil.html`).toString();
  }

  enHTML = () => (this.infosUtilisateur
    ? this.avecUtilisateurConnecte()
    : this.sansUtilisateurConnecte());

  avecUtilisateurConnecte() {
    return this.modeleVierge.replace(
      '{{contenu}}',
      `<p>Utilisateur courant : ${this.infosUtilisateur.given_name} ${this.infosUtilisateur.family_name}</p>
                <a href="/auth/fcplus/destructionSession">Déconnexion</a>`,
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
