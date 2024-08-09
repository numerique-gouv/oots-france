const { ErreurCodeDemarcheIntrouvable, ErreurCodePaysIntrouvable, ErreurTypeJustificatifIntrouvable } = require('../erreurs');
const adaptateurEnvironnement = require('../adaptateurs/adaptateurEnvironnement');
const Fournisseur = require('../ebms/fournisseur');
const TypeJustificatif = require('../ebms/typeJustificatif');

class DepotServicesCommunsLocal {
  constructor(donnees = adaptateurEnvironnement.donneesDepotServicesCommunsLocal()) {
    this.donnees = donnees;
  }

  trouveFournisseurs(idTypeJustificatif, codePays) {
    const fournisseurs = this.donnees
      ?.typesJustificatif
      ?.find((tj) => tj.id === idTypeJustificatif)
      ?.fournisseurs
      ?.[codePays]
      ?.map((f) => new Fournisseur(f));

    if (typeof fournisseurs === 'undefined') {
      return Promise.reject(new ErreurCodePaysIntrouvable(`Code pays "${codePays}" introuvable`));
    }

    return Promise.resolve(fournisseurs);
  }

  trouveTypeJustificatif(id) {
    const donneesTypeJustificatif = this.donnees?.typesJustificatif?.find((tj) => tj.id === id);
    if (typeof donneesTypeJustificatif === 'undefined') {
      return Promise.reject(new ErreurTypeJustificatifIntrouvable(`Type justificatif avec identifiant "${id}" introuvable`));
    }

    const typeJustificatif = new TypeJustificatif(donneesTypeJustificatif);
    return Promise.resolve(typeJustificatif);
  }

  trouveTypesJustificatifsPourDemarche(code) {
    const typesJustificatifs = this.donnees
      ?.demarches
      ?.find((d) => d.code === code)
      ?.idsTypeJustificatif
      ?.map((id) => this.trouveTypeJustificatif(id));

    if (typeof typesJustificatifs === 'undefined') {
      return Promise.reject(new ErreurCodeDemarcheIntrouvable(`Code démarche "${code}" introuvable`));
    }

    return Promise.all(typesJustificatifs);
  }
}

module.exports = DepotServicesCommunsLocal;
