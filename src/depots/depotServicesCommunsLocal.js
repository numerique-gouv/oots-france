const { ErreurCodeDemarcheIntrouvable, ErreurCodePaysIntrouvable, ErreurTypeJustificatifIntrouvable } = require('../erreurs');
const Fournisseur = require('../ebms/fournisseur');
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
    fournisseurs: {
      FR: [{
        pointAcces: {
          id: 'blue_gw',
          systeme: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR',
        },
        descriptions: { EN: 'French Intermediary Platform' },
      }],
    },
  }],
};

class DepotServicesCommunsLocal {
  constructor(donnees = DONNEES_DEPOT) {
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
