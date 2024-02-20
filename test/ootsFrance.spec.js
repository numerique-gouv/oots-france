const axios = require('axios');

const { parseXML } = require('./ebms/utils');
const { ErreurAbsenceReponseDestinataire } = require('../src/erreurs');
const OOTS_FRANCE = require('../src/ootsFrance');

describe('Le serveur OOTS France', () => {
  const adaptateurChiffrement = {};
  const adaptateurDomibus = {};
  const adaptateurEnvironnement = {};
  const adaptateurFranceConnectPlus = {};
  const adaptateurUUID = {};
  const depotPointsAcces = {};
  const ecouteurDomibus = {};
  const horodateur = {};

  let port;
  let serveur;

  beforeEach((suite) => {
    adaptateurChiffrement.cleHachage = () => '';
    adaptateurChiffrement.genereJeton = () => Promise.resolve();
    adaptateurEnvironnement.avecRequetePieceJustificative = () => 'true';
    adaptateurEnvironnement.avecEnvoiCookieSurHTTP = () => 'true';
    adaptateurEnvironnement.secretJetonSession = () => 'secret';
    adaptateurFranceConnectPlus.recupereInfosUtilisateur = () => Promise.resolve({});
    adaptateurUUID.genereUUID = () => '';
    depotPointsAcces.trouvePointAcces = () => Promise.resolve({});
    ecouteurDomibus.arreteEcoute = () => {};
    ecouteurDomibus.etat = () => '';
    horodateur.maintenant = () => '';

    serveur = OOTS_FRANCE.creeServeur({
      adaptateurChiffrement,
      adaptateurDomibus,
      adaptateurEnvironnement,
      adaptateurFranceConnectPlus,
      adaptateurUUID,
      depotPointsAcces,
      ecouteurDomibus,
      horodateur,
    });
    serveur.ecoute(0, () => {
      port = serveur.port();
      suite();
    });
  });

  afterEach((suite) => {
    serveur.arreteEcoute(suite);
  });

  describe('sur GET /ebms/entetes/requeteJustificatif', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/entetes/requeteJustificatif`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
      }));

    it('génère un identifiant unique de conversation', () => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      return axios.get(`http://localhost:${port}/ebms/entetes/requeteJustificatif`)
        .then((reponse) => {
          const xml = parseXML(reponse.data);
          const idConversation = xml.Messaging.UserMessage.CollaborationInfo.ConversationId;
          expect(idConversation).toEqual('11111111-1111-1111-1111-111111111111');
        });
    });
  });

  describe('sur GET /ebms/messages/requeteJustificatif', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/messages/requeteJustificatif`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
      }));

    it('génère un identifiant unique de requête', () => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      return axios.get(`http://localhost:${port}/ebms/messages/requeteJustificatif`)
        .then((reponse) => {
          const xml = parseXML(reponse.data);
          const requestId = xml.QueryRequest['@_id'];
          expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
        });
    });
  });

  describe('sur GET /ebms/messages/reponseErreur', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/messages/reponseErreur`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
      }));
  });

  describe('sur GET /requete/pieceJustificative', () => {
    beforeEach(() => {
      adaptateurDomibus.envoieMessageRequete = () => Promise.resolve();
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL reçue'));
      adaptateurDomibus.pieceJustificativeDepuisReponse = () => Promise.resolve(Buffer.from(''));
    });

    describe('avec un destinataire qui ne répond pas', () => {
      it('retourne une erreur HTTP 504 (Gateway Timeout)', () => {
        expect.assertions(2);

        adaptateurDomibus.pieceJustificativeDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune pièce reçue'));
        return axios.get(`http://localhost:${port}/requete/pieceJustificative?destinataire=DESTINATAIRE_SILENCIEUX`)
          .catch(({ response }) => {
            expect(response.status).toEqual(504);
            expect(response.data).toEqual({ erreur: 'aucune URL reçue ; aucune pièce reçue' });
          });
      });
    });

    it('retourne une erreur 501 quand le feature flip est désactivé', () => {
      expect.assertions(2);

      adaptateurEnvironnement.avecRequetePieceJustificative = () => false;

      return axios.get(`http://localhost:${port}/requete/pieceJustificative?destinataire=AP_FR_01`)
        .catch(({ response }) => {
          expect(response.status).toEqual(501);
          expect(response.data).toEqual('Not Implemented Yet!');
        });
    });
  });

  describe('sur GET /', () => {
    beforeEach(() => {
      adaptateurChiffrement.verifieJeton = () => Promise.resolve();
    });

    it("affiche qu'il n'y a pas pas d'utilisateur courant par défaut", () => (
      axios.get(`http://localhost:${port}/`)
        .then((reponse) => {
          expect(reponse.status).toBe(200);
          expect(reponse.data).toContain("Pas d'utilisateur courant");
        })
    ));

    it("affiche prénom et nom de l'utilisateur courant s'il existe", () => {
      adaptateurChiffrement.verifieJeton = () => Promise.resolve({
        given_name: 'Sandra',
        family_name: 'Nicouette',
      });

      return axios.get(`http://localhost:${port}/`)
        .then((reponse) => {
          expect(reponse.status).toBe(200);
          expect(reponse.data).toContain('Utilisateur courant : Sandra Nicouette');
        });
    });
  });
});
