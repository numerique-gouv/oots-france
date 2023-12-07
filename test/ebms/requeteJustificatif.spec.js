const { XMLParser } = require('fast-xml-parser');

const { verifiePresenceSlot, valeurSlot } = require('./utils');
const RequeteJustificatif = require('../../src/ebms/requeteJustificatif');

describe("La vue du message de requête d'un justificatif", () => {
  const parser = new XMLParser({ ignoreAttributes: false });
  const adaptateurUUID = {};
  const horodateur = {};
  const configurationRequete = { adaptateurUUID, horodateur };

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => '';
    horodateur.maintenant = () => '';
  });

  it('injecte un identifiant unique de requête', () => {
    adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';
    const requeteJustificatif = new RequeteJustificatif(configurationRequete);

    const xml = parser.parse(requeteJustificatif.enXML());
    const requestId = xml['query:QueryRequest']['@_id'];
    expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
  });

  it('respecte la structure définie par OOTS', () => {
    const requeteJustificatif = new RequeteJustificatif(configurationRequete);
    const xml = parser.parse(requeteJustificatif.enXML());

    const scopeRechercheQueryRequest = xml['query:QueryRequest'];
    verifiePresenceSlot('SpecificationIdentifier', scopeRechercheQueryRequest);
    verifiePresenceSlot('IssueDateTime', scopeRechercheQueryRequest);
    verifiePresenceSlot('Procedure', scopeRechercheQueryRequest);
    verifiePresenceSlot('PossibilityForPreview', scopeRechercheQueryRequest);
    verifiePresenceSlot('ExplicitRequestGiven', scopeRechercheQueryRequest);
    verifiePresenceSlot('Requirements', scopeRechercheQueryRequest);
    verifiePresenceSlot('EvidenceRequester', scopeRechercheQueryRequest);
    verifiePresenceSlot('EvidenceProvider', scopeRechercheQueryRequest);

    const scopeRechercheQuery = xml['query:QueryRequest']['query:Query'];
    verifiePresenceSlot('EvidenceRequest', scopeRechercheQuery);
    verifiePresenceSlot('NaturalPerson', scopeRechercheQuery);
    expect(scopeRechercheQuery['@_queryDefinition']).toEqual('DocumentQuery');

    expect(xml['query:QueryRequest']['query:ResponseOption']).toBeDefined();
    expect(xml['query:QueryRequest']['query:ResponseOption']['@_returnType']).toEqual('LeafClassWithRepositoryItem');
  });

  it('injecte la demande de prévisualisation', () => {
    const requeteJustificatif = new RequeteJustificatif(
      configurationRequete,
      { previsualisationRequise: false },
    );
    const xml = parser.parse(requeteJustificatif.enXML());

    const demandePrevisualisation = valeurSlot('PossibilityForPreview', xml['query:QueryRequest']);
    expect(demandePrevisualisation).toBe(false);
  });

  it('injecte le code de la démarche administrative (en anglais, « procedure »)', () => {
    const requeteJustificatif = new RequeteJustificatif(
      configurationRequete,
      { codeDemarche: 'T3' },
    );
    const xml = parser.parse(requeteJustificatif.enXML());

    const codeDemarche = valeurSlot('Procedure', xml['query:QueryRequest']);
    expect(codeDemarche['rim:LocalizedString']['@_value']).toBe('T3');
  });
});
