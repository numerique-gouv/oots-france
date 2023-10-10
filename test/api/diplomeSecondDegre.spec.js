const diplomeSecondDegre = require('../../src/api/diplomeSecondDegre');
const { ErreurAbsenceReponseDestinataire } = require('../../src/erreurs');

describe('Le requêteur de diplôme du second degré', () => {
  const adaptateurUUID = {};
  const adaptateurDomibus = {};
  const requete = {};
  const reponse = {};

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => '';
    adaptateurDomibus.envoieMessageRequete = () => Promise.resolve();
    adaptateurDomibus.pieceJustificativeDepuisReponse = () => Promise.resolve();
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve();

    requete.query = {};
    reponse.send = () => Promise.resolve();
    reponse.status = () => reponse;
    reponse.redirect = () => Promise.resolve();
  });

  it('envoie un message AS4 au bon destinataire', (suite) => {
    requete.query.destinataire = 'UN_DESTINATAIRE';

    adaptateurDomibus.envoieMessageRequete = (destinataire) => {
      try {
        expect(destinataire).toEqual('UN_DESTINATAIRE');
        return Promise.resolve();
      } catch (e) { return Promise.reject(e); }
    };

    diplomeSecondDegre(adaptateurDomibus, adaptateurUUID, requete, reponse)
      .then(() => suite())
      .catch(suite);
  });

  it('utilise un identifiant de conversation', (suite) => {
    adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

    adaptateurDomibus.envoieMessageRequete = (_destinataire, idConversation) => {
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

    diplomeSecondDegre(adaptateurDomibus, adaptateurUUID, requete, reponse)
      .then(() => suite())
      .catch(suite);
  });

  describe('quand `process.env.URL_OOTS_FRANCE` vaut `https://localhost:1234`', () => {
    let urlOotsFrance;

    beforeEach(() => {
      urlOotsFrance = process.env.URL_OOTS_FRANCE;
    });

    afterEach(() => {
      process.env.URL_OOTS_FRANCE = urlOotsFrance;
    });

    it("construis l'URL de redirection", (suite) => {
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve('https://example.com');
      process.env.URL_OOTS_FRANCE = 'http://localhost:1234';

      reponse.redirect = (urlRedirection) => {
        try {
          expect(urlRedirection).toEqual('https://example.com?returnurl=http://localhost:1234');
          return Promise.resolve();
        } catch (e) { return Promise.reject(e); }
      };

      diplomeSecondDegre(adaptateurDomibus, adaptateurUUID, requete, reponse)
        .then(() => suite())
        .catch(suite);
    });
  });

  it('accepte de recevoir directement la pièce justificative', (suite) => {
    let pieceJustificativeRecue = false;
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('Aucune URL de redirection reçue'));
    adaptateurDomibus.pieceJustificativeDepuisReponse = () => {
      pieceJustificativeRecue = true;
      return Promise.resolve();
    };

    diplomeSecondDegre(adaptateurDomibus, adaptateurUUID, requete, reponse)
      .then(() => expect(pieceJustificativeRecue).toBe(true))
      .then(() => suite())
      .catch(suite);
  });
});
