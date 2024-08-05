const pieceJustificative = require('../../src/api/pieceJustificative');
const PointAcces = require('../../src/ebms/pointAcces');

const {
  ErreurAbsenceReponseDestinataire,
  ErreurReponseRequete,
  ErreurDestinataireInexistant,
} = require('../../src/erreurs');

describe('Le requêteur de pièce justificative', () => {
  const adaptateurDomibus = {};
  const adaptateurEnvironnement = {};
  const adaptateurUUID = {};
  const depotPointsAcces = {};
  const depotServicesCommuns = {};

  const config = {
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    depotPointsAcces,
    depotServicesCommuns,
  };
  const requete = {};
  const reponse = {};

  beforeEach(() => {
    adaptateurDomibus.envoieMessageRequete = () => Promise.resolve();
    adaptateurDomibus.pieceJustificativeDepuisReponse = () => Promise.resolve();
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve();
    adaptateurUUID.genereUUID = () => '';
    depotPointsAcces.trouvePointAcces = () => Promise.resolve({});
    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = () => Promise.resolve([]);

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
        return Promise.resolve([]);
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
    adaptateurDomibus.pieceJustificativeDepuisReponse = () => {
      pieceJustificativeRecue = true;
      return Promise.resolve();
    };

    return pieceJustificative(config, requete, reponse)
      .then(() => expect(pieceJustificativeRecue).toBe(true));
  });

  it("génère une erreur HTTP 502 (Bad Gateway) sur réception d'une réponse en erreur", () => {
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurReponseRequete('object not found'));
    adaptateurDomibus.pieceJustificativeDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucun justificatif reçu'));

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
