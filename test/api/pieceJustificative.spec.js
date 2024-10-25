const pieceJustificative = require('../../src/api/pieceJustificative');
const PointAcces = require('../../src/ebms/pointAcces');
const Fournisseur = require('../../src/ebms/fournisseur');
const Requeteur = require('../../src/ebms/requeteur');
const TypeJustificatif = require('../../src/ebms/typeJustificatif');

const {
  ErreurAbsenceReponseDestinataire,
  ErreurDestinataireInexistant,
  ErreurRequeteurInexistant,
  ErreurReponseRequete,
} = require('../../src/erreurs');

describe('Le requêteur de pièce justificative', () => {
  const adaptateurDomibus = {};
  const adaptateurEnvironnement = {};
  const adaptateurUUID = {};
  const depotPointsAcces = {};
  const depotRequeteurs = {};
  const depotServicesCommuns = {};

  const config = {
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    depotPointsAcces,
    depotRequeteurs,
    depotServicesCommuns,
  };
  const requete = {};
  const reponse = {};

  beforeEach(() => {
    adaptateurDomibus.envoieMessageRequete = () => Promise.resolve();
    adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.resolve();
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve();
    adaptateurUUID.genereUUID = () => '';
    depotPointsAcces.trouvePointAcces = () => Promise.resolve({});
    depotRequeteurs.trouveRequeteur = () => Promise.resolve(new Requeteur());
    depotServicesCommuns.trouveFournisseurs = () => Promise.resolve([new Fournisseur()]);
    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = () => Promise.resolve(
      [new TypeJustificatif()],
    );

    requete.query = {};
    reponse.json = () => Promise.resolve();
    reponse.redirect = () => Promise.resolve();
    reponse.send = () => Promise.resolve();
    reponse.status = () => reponse;
  });

  it('envoie un message AS4 au bon destinataire', () => {
    depotPointsAcces.trouvePointAcces = () => Promise.resolve(new PointAcces('unIdentifiant', 'unType'));

    adaptateurDomibus.envoieMessageRequete = ({ destinataire }) => {
      try {
        expect(destinataire.id).toEqual('unIdentifiant');
        expect(destinataire.typeId).toEqual('unType');
        return Promise.resolve();
      } catch (e) {
        return Promise.reject(e);
      }
    };

    return pieceJustificative(config, requete, reponse);
  });

  it('transmet le code démarche dans la requête', () => {
    requete.query.codeDemarche = 'UN_CODE';

    adaptateurDomibus.envoieMessageRequete = ({ codeDemarche }) => {
      try {
        expect(codeDemarche).toEqual('UN_CODE');
        return Promise.resolve();
      } catch (e) {
        return Promise.reject(e);
      }
    };

    return pieceJustificative(config, requete, reponse);
  });

  it('interroge dépôt services communs pour récupérer infos relatives au code démarche', () => {
    expect.assertions(1);
    requete.query.codeDemarche = '00';

    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = (code) => {
      try {
        expect(code).toBe('00');
        return Promise.resolve([new TypeJustificatif()]);
      } catch (e) {
        return Promise.reject(e);
      }
    };

    return pieceJustificative(config, requete, reponse);
  });

  it("transmet l'identifiant de type de pièce justificative demandée", () => {
    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = () => Promise.resolve([{ id: 'unIdentifiant' }]);

    adaptateurDomibus.envoieMessageRequete = ({ typeJustificatif }) => {
      try {
        expect(typeJustificatif.id).toEqual('unIdentifiant');
        return Promise.resolve();
      } catch (e) {
        return Promise.reject(e);
      }
    };

    return pieceJustificative(config, requete, reponse);
  });

  it('interroge dépôt services communs pour récupérer fournisseurs relatifs au justificatif et au code pays', () => {
    expect.assertions(2);
    requete.query.codePays = 'FR';
    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = () => Promise.resolve([{ id: 'unIdentifiant' }]);

    depotServicesCommuns.trouveFournisseurs = (idTypeJustificatif, codePays) => {
      try {
        expect(idTypeJustificatif).toBe('unIdentifiant');
        expect(codePays).toBe('FR');
        return Promise.resolve([new Fournisseur()]);
      } catch (e) {
        return Promise.reject(e);
      }
    };

    return pieceJustificative(config, requete, reponse);
  });

  it('transmet fournisseur à requête', () => {
    expect.assertions(1);

    depotServicesCommuns.trouveFournisseurs = () => (
      Promise.resolve([new Fournisseur({ descriptions: { FR: 'Un fournisseur' } })])
    );

    adaptateurDomibus.envoieMessageRequete = ({ fournisseur }) => {
      try {
        expect(fournisseur.descriptions.FR).toBe('Un fournisseur');
        return Promise.resolve();
      } catch (e) {
        return Promise.reject(e);
      }
    };

    return pieceJustificative(config, requete, reponse);
  });

  it('interroge le dépôt de requêteurs', () => {
    expect.assertions(1);
    requete.query.idRequeteur = '123456';

    depotRequeteurs.trouveRequeteur = (id) => {
      expect(id).toBe('123456');
      return Promise.resolve(new Requeteur());
    };

    return pieceJustificative(config, requete, reponse);
  });

  it('transmet requêteur à requête', () => {
    expect.assertions(1);
    depotRequeteurs.trouveRequeteur = () => Promise.resolve(new Requeteur({ nom: 'Un requêteur' }));

    adaptateurDomibus.envoieMessageRequete = ({ requeteur }) => {
      expect(requeteur.nom).toBe('Un requêteur');
      return Promise.resolve();
    };

    return pieceJustificative(config, requete, reponse);
  });

  it("génère une erreur 422 lorsque le requêteur n'existe pas", () => {
    requete.query.idRequeteur = 'requeteurInexistant';
    depotRequeteurs.trouveRequeteur = () => Promise.reject(new ErreurRequeteurInexistant('Oups'));

    reponse.status = (codeStatus) => {
      expect(codeStatus).toEqual(422);
      return reponse;
    };
    reponse.json = (contenu) => {
      expect(contenu).toEqual({ erreur: 'Oups' });
    };

    return pieceJustificative(config, requete, reponse);
  });

  it('utilise un identifiant de conversation', () => {
    adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

    adaptateurDomibus.envoieMessageRequete = ({ idConversation }) => {
      try {
        expect(idConversation).toEqual('11111111-1111-1111-1111-111111111111');
        return Promise.resolve();
      } catch (e) { return Promise.reject(e); }
    };

    adaptateurDomibus.urlRedirectionDepuisReponse = (idConversation) => {
      try {
        expect(idConversation).toEqual('11111111-1111-1111-1111-111111111111');
        return Promise.resolve();
      } catch (e) { return Promise.reject(e); }
    };

    return pieceJustificative(config, requete, reponse);
  });

  describe('quand `process.env.URL_OOTS_FRANCE` vaut `https://localhost:1234`', () => {
    let urlOotsFrance;

    beforeEach(() => {
      urlOotsFrance = process.env.URL_OOTS_FRANCE;
    });

    afterEach(() => {
      process.env.URL_OOTS_FRANCE = urlOotsFrance;
    });

    it("construis l'URL de redirection", () => {
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve('https://example.com');
      process.env.URL_OOTS_FRANCE = 'http://localhost:1234';

      reponse.redirect = (urlRedirection) => {
        try {
          expect(urlRedirection).toEqual('https://example.com?returnurl=http://localhost:1234');
          return Promise.resolve();
        } catch (e) { return Promise.reject(e); }
      };

      return pieceJustificative(config, requete, reponse);
    });
  });

  it('accepte de recevoir directement la pièce justificative', () => {
    let pieceJustificativeRecue = false;
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL de redirection reçue'));
    adaptateurDomibus.reponseAvecPieceJustificative = () => {
      pieceJustificativeRecue = true;
      return Promise.resolve();
    };

    return pieceJustificative(config, requete, reponse)
      .then(() => expect(pieceJustificativeRecue).toBe(true));
  });

  it("génère une erreur HTTP 502 (Bad Gateway) sur réception d'une réponse en erreur", () => {
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurReponseRequete('object not found'));
    adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucun justificatif reçu'));

    reponse.status = (codeStatus) => {
      expect(codeStatus).toEqual(502);
      return reponse;
    };

    reponse.json = (contenu) => {
      expect(contenu).toEqual({ erreur: 'object not found ; aucun justificatif reçu' });
    };

    return pieceJustificative(config, requete, reponse);
  });

  it("génère une erreur 422 lorsque le destinataire n'existe pas", () => {
    requete.query.destinataire = 'DESTINATAIRE_INEXISTANT';
    depotPointsAcces.trouvePointAcces = () => Promise.reject(new ErreurDestinataireInexistant('Oups'));

    reponse.status = (codeStatus) => {
      expect(codeStatus).toEqual(422);
      return reponse;
    };
    reponse.json = (contenu) => {
      expect(contenu).toEqual({ erreur: 'Oups' });
    };

    return pieceJustificative(config, requete, reponse);
  });
});
