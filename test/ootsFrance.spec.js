const axios = require('axios');
const { XMLParser } = require('fast-xml-parser');

const OOTS_FRANCE = require('../src/ootsFrance');

describe('Le serveur OOTS France', () => {
  const adaptateurUUID = {};
  const adaptateurDomibus = {};
  let serveur;

  beforeEach((suite) => {
    adaptateurUUID.genereUUID = () => '';
    serveur = OOTS_FRANCE.creeServeur({ adaptateurDomibus, adaptateurUUID });
    serveur.ecoute(1234, suite);
  });

  afterEach(() => { serveur.arreteEcoute(); });

  describe('sur GET /response/educationEvidence', () => {
    it('sert une réponse au format XML', (suite) => {
      axios.get('http://localhost:1234/response/educationEvidence')
        .then((reponse) => {
          expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
          suite();
        })
        .catch(suite);
    });

    it('génère un identifiant unique de requête', (suite) => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      axios.get('http://localhost:1234/response/educationEvidence')
        .then((reponse) => {
          const parser = new XMLParser({ ignoreAttributes: false });
          const xml = parser.parse(reponse.data);
          const requestId = xml['query:QueryResponse']['@_requestId'];
          expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
          suite();
        })
        .catch(suite);
    });

    it('respecte la structure définie par OOTS', (suite) => {
      axios.get('http://localhost:1234/response/educationEvidence')
        .then((reponse) => {
          const parser = new XMLParser({ ignoreAttributes: false });
          const xml = parser.parse(reponse.data);

          expect(xml['query:QueryResponse']['rim:RegistryObjectList']).toBeDefined();

          const slots = [].concat(xml['query:QueryResponse']['rim:Slot']);
          expect(slots.some((s) => s['@_name'] === 'SpecificationIdentifier')).toBe(true);
          expect(slots.some((s) => s['@_name'] === 'EvidenceResponseIdentifier')).toBe(true);
          expect(slots.some((s) => s['@_name'] === 'IssueDateTime')).toBe(true);
          expect(slots.some((s) => s['@_name'] === 'EvidenceProvider')).toBe(true);
          expect(slots.some((s) => s['@_name'] === 'EvidenceRequester')).toBe(true);

          suite();
        })
        .catch(suite);
    });
  });

  describe('sur GET /messageRequeteJustificatif', () => {
    it('sert une réponse au format XML', (suite) => {
      axios.get('http://localhost:1234/messageRequeteJustificatif')
        .then((reponse) => {
          expect(reponse.headers['content-type']).toEqual('text/xml; charset=utf-8');
          suite();
        })
        .catch(suite);
    });

    it('génère un identifiant unique de requête', (suite) => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      axios.get('http://localhost:1234/messageRequeteJustificatif')
        .then((reponse) => {
          const parser = new XMLParser({ ignoreAttributes: false });
          const xml = parser.parse(reponse.data);
          const requestId = xml['query:QueryRequest']['@_id'];
          expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
          suite();
        })
        .catch(suite);
    });
  });

  it('sert une erreur HTTP 504 (not implemented)', (suite) => {
    axios.get('http://localhost:1234/')
      .then(() => suite('Réponse OK inattendue'))
      .catch((erreur) => {
        expect(erreur.response.status).toEqual(504);
        suite();
      })
      .catch(suite);
  });
});
