const axios = require('axios');

const serveurTest = require('./serveurTest');
const leveErreur = require('./utils');
const { parseXML } = require('../ebms/utils');

describe('Le serveur des routes `/ebms`', () => {
  const serveur = serveurTest();
  let port;

  beforeEach((suite) => serveur.initialise(() => {
    port = serveur.port();
    suite();
  }));

  afterEach((suite) => serveur.arrete(suite));

  describe('sur GET /ebms/entetes/requeteJustificatif', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/entetes/requeteJustificatif`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
      })
      .catch(leveErreur));

    it('génère un identifiant unique de conversation', () => {
      serveur.adaptateurUUID().genereUUID = () => '11111111-1111-1111-1111-111111111111';

      return axios.get(`http://localhost:${port}/ebms/entetes/requeteJustificatif`)
        .then((reponse) => {
          const xml = parseXML(reponse.data);
          const idConversation = xml.Messaging.UserMessage.CollaborationInfo.ConversationId;
          expect(idConversation).toEqual('11111111-1111-1111-1111-111111111111');
        })
        .catch(leveErreur);
    });
  });

  describe('sur GET /ebms/messages/requeteJustificatif', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/messages/requeteJustificatif`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
      })
      .catch(leveErreur));

    it('génère un identifiant unique de requête', () => {
      serveur.adaptateurUUID().genereUUID = () => '11111111-1111-1111-1111-111111111111';

      return axios.get(`http://localhost:${port}/ebms/messages/requeteJustificatif`)
        .then((reponse) => {
          const xml = parseXML(reponse.data);
          const requestId = xml.QueryRequest['@_id'];
          expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
        })
        .catch(leveErreur);
    });
  });

  describe('sur GET /ebms/messages/reponseErreur', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/messages/reponseErreur`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
      })
      .catch(leveErreur));
  });

  describe('sur GET /ebms/messages/reponseJustificatif', () => {
    it('sert une réponse au format XML', () => axios.get(`http://localhost:${port}/ebms/messages/reponseJustificatif`)
      .then((reponse) => {
        expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
      })
      .catch(leveErreur));
  });
});
