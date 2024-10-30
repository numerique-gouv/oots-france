const axios = require('axios');

const serveurTest = require('./serveurTest');
const {
  ErreurAbsenceReponseDestinataire,
  ErreurCodeDemarcheIntrouvable,
  ErreurCodePaysIntrouvable,
  ErreurTypeJustificatifIntrouvable,
} = require('../../src/erreurs');

describe('Le serveur des routes `/requete`', () => {
  const serveur = serveurTest();
  let port;

  beforeEach((suite) => serveur.initialise(() => {
    port = serveur.port();
    suite();
  }));

  afterEach((suite) => serveur.arrete(suite));

  describe('sur GET /requete/pieceJustificative', () => {
    describe('avec un destinataire qui ne répond pas', () => {
      it('retourne une erreur HTTP 504 (Gateway Timeout)', () => {
        expect.assertions(2);

        serveur.adaptateurDomibus().reponseAvecPieceJustificative = (
          () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune pièce reçue'))
        );

        return axios.get(`http://localhost:${port}/requete/pieceJustificative?destinataire=DESTINATAIRE_SILENCIEUX`)
          .catch(({ response }) => {
            expect(response.status).toEqual(504);
            expect(response.data).toEqual({ erreur: 'aucune URL reçue ; aucune pièce reçue' });
          });
      });
    });
  });

  it('retourne une erreur HTTP 422 (Unprocessable Content) si le type de justificatif est introuvable', () => {
    serveur.depotServicesCommuns().trouveTypesJustificatifsPourDemarche = () => Promise.resolve([
      Promise.reject(new ErreurTypeJustificatifIntrouvable('oups')),
    ]);

    return axios.get(`http://localhost:${port}/requete/pieceJustificative`)
      .catch(({ response }) => {
        expect(response.status).toEqual(422);
        expect(response.data).toEqual({ erreur: 'oups' });
      });
  });

  it('retourne une erreur HTTP 422 (Unprocessable Content) si le code démarche est introuvable', () => {
    serveur.depotServicesCommuns().trouveTypesJustificatifsPourDemarche = () => (
      Promise.reject(new ErreurCodeDemarcheIntrouvable('oups'))
    );

    return axios.get(`http://localhost:${port}/requete/pieceJustificative`)
      .catch(({ response }) => {
        expect(response.status).toEqual(422);
        expect(response.data).toEqual({ erreur: 'oups' });
      });
  });

  it('retourne une erreur HTTP 422 (Unprocessable Content) si le code pays est introuvable', () => {
    serveur.depotServicesCommuns().trouveFournisseurs = () => (
      Promise.reject(new ErreurCodePaysIntrouvable('oups'))
    );

    return axios.get(`http://localhost:${port}/requete/pieceJustificative`)
      .catch(({ response }) => {
        expect(response.status).toEqual(422);
        expect(response.data).toEqual({ erreur: 'oups' });
      });
  });

  it('retourne une erreur 501 quand le feature flip est désactivé', () => {
    expect.assertions(2);

    serveur.adaptateurEnvironnement().avecRequetePieceJustificative = () => false;

    return axios.get(`http://localhost:${port}/requete/pieceJustificative?destinataire=AP_FR_01`)
      .catch(({ response }) => {
        expect(response.status).toEqual(501);
        expect(response.data).toEqual('Not Implemented Yet!');
      });
  });
});
