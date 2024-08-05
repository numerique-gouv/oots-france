const { ErreurCodeDemarcheIntrouvable, ErreurTypeJustificatifIntrouvable } = require('../erreurs');
const TypeJustificatif = require('../ebms/typeJustificatif');

const DONNEES_DEPOT = {
  demarches: [{
    code: '00',
    idsTypeJustificatif: ['https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000'],
  }],

  typesJustificatif: [{
    id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/oots/00000000-0000-0000-0000-000000000000',
    descriptions: { EN: 'System Health Check' },
    formatDistribution: 'application/pdf',
  }],
};

class DepotServicesCommunsLocal {
  constructor(donnees = DONNEES_DEPOT) {
    this.donnees = donnees;
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
