const axios = require('axios');

const { parseXML, verifiePresenceSlot } = require('./ebms/utils');
const { ErreurAbsenceReponseDestinataire } = require('../src/erreurs');
const OOTS_FRANCE = require('../src/ootsFrance');

describe('Le serveur OOTS France', () => {
  const adaptateurDomibus = {};
  const adaptateurEnvironnement = {};
  const adaptateurUUID = {};
  const depotPointsAcces = {};
  const ecouteurDomibus = {};
  const horodateur = {};

  let port;
  let serveur;

  beforeEach((suite) => {
    adaptateurEnvironnement.avecRequetePieceJustificative = () => 'true';
    adaptateurUUID.genereUUID = () => '';
    depotPointsAcces.trouvePointAcces = () => Promise.resolve({});
    ecouteurDomibus.arreteEcoute = () => {};
    ecouteurDomibus.etat = () => '';
    horodateur.maintenant = () => '';

    serveur = OOTS_FRANCE.creeServeur({
      adaptateurDomibus,
      adaptateurEnvironnement,
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

  describe('sur GET /response/educationEvidence', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/response/educationEvidence`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
      }));

    it('génère un identifiant unique de requête', () => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      return axios.get(`http://localhost:${port}/response/educationEvidence`)
        .then((reponse) => {
          const xml = parseXML(reponse.data);
          const requestId = xml.QueryResponse['@_requestId'];
          expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
        });
    });

    it('respecte la structure définie par OOTS', () => axios.get(`http://localhost:${port}/response/educationEvidence`)
      .then((reponse) => {
        const xml = parseXML(reponse.data);

        expect(xml.QueryResponse.RegistryObjectList).toBeDefined();

        verifiePresenceSlot('SpecificationIdentifier', xml.QueryResponse);
        verifiePresenceSlot('SpecificationIdentifier', xml.QueryResponse);
        verifiePresenceSlot('EvidenceResponseIdentifier', xml.QueryResponse);
        verifiePresenceSlot('IssueDateTime', xml.QueryResponse);
        verifiePresenceSlot('EvidenceProvider', xml.QueryResponse);
        verifiePresenceSlot('EvidenceRequester', xml.QueryResponse);
      }));
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

  describe('sur POST /admin/arretEcouteDomibus', () => {
    it("arrête d'écouter Domibus", () => {
      let arretEcoute = false;
      ecouteurDomibus.arreteEcoute = () => {
        arretEcoute = true;
      };

      return axios.post(`http://localhost:${port}/admin/arretEcouteDomibus`)
        .then(() => expect(arretEcoute).toBe(true));
    });

    it("retourne le nouvel état de l'écouteur", () => {
      ecouteurDomibus.etat = () => 'nouvel état';

      return axios.post(`http://localhost:${port}/admin/arretEcouteDomibus`)
        .then((reponse) => expect(reponse.data).toEqual({ etatEcouteur: 'nouvel état' }));
    });
  });

  describe('sur POST /admin/demarrageEcouteDomibus', () => {
    it('écoute Domibus', () => {
      let demarreEcoute = false;
      ecouteurDomibus.ecoute = () => {
        demarreEcoute = true;
      };

      return axios.post(`http://localhost:${port}/admin/demarrageEcouteDomibus`)
        .then(() => expect(demarreEcoute).toBe(true));
    });

    it("retourne le nouvel état de l'écouteur", () => {
      ecouteurDomibus.etat = () => 'nouvel état';

      return axios.post(`http://localhost:${port}/admin/demarrageEcouteDomibus`)
        .then((reponse) => expect(reponse.data).toEqual({ etatEcouteur: 'nouvel état' }));
    });
  });

  describe('sur GET /', () => {
    it('sert une erreur HTTP 501 (not implemented)', () => {
      expect.assertions(1);

      return axios.get(`http://localhost:${port}/`)
        .catch((erreur) => expect(erreur.response.status).toEqual(501));
    });
  });
});
