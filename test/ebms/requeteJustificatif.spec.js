const { parseXML, verifiePresenceSlot, valeurSlot } = require('./utils');
const RequeteJustificatif = require('../../src/ebms/requeteJustificatif');

describe("La vue du message de requête d'un justificatif", () => {
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

    const xml = parseXML(requeteJustificatif.corpsMessageEnXML());
    const requestId = xml.QueryRequest['@_id'];
    expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
  });

  it('respecte la structure définie par OOTS', () => {
    const requeteJustificatif = new RequeteJustificatif(configurationRequete);
    const xml = parseXML(requeteJustificatif.corpsMessageEnXML());

    const scopeRechercheQueryRequest = xml.QueryRequest;
    verifiePresenceSlot('SpecificationIdentifier', scopeRechercheQueryRequest);
    verifiePresenceSlot('IssueDateTime', scopeRechercheQueryRequest);
    verifiePresenceSlot('Procedure', scopeRechercheQueryRequest);
    verifiePresenceSlot('PossibilityForPreview', scopeRechercheQueryRequest);
    verifiePresenceSlot('ExplicitRequestGiven', scopeRechercheQueryRequest);
    verifiePresenceSlot('Requirements', scopeRechercheQueryRequest);
    verifiePresenceSlot('EvidenceRequester', scopeRechercheQueryRequest);
    verifiePresenceSlot('EvidenceProvider', scopeRechercheQueryRequest);

    const scopeRechercheQuery = xml.QueryRequest.Query;
    verifiePresenceSlot('EvidenceRequest', scopeRechercheQuery);
    verifiePresenceSlot('NaturalPerson', scopeRechercheQuery);
    expect(scopeRechercheQuery['@_queryDefinition']).toEqual('DocumentQuery');

    expect(xml.QueryRequest.ResponseOption).toBeDefined();
    expect(xml.QueryRequest.ResponseOption['@_returnType']).toEqual('LeafClassWithRepositoryItem');
  });

  it('injecte la demande de prévisualisation', () => {
    const requeteJustificatif = new RequeteJustificatif(
      configurationRequete,
      { previsualisationRequise: false },
    );
    const xml = parseXML(requeteJustificatif.corpsMessageEnXML());

    const demandePrevisualisation = valeurSlot('PossibilityForPreview', xml.QueryRequest);
    expect(demandePrevisualisation).toBe(false);
  });

  it('injecte le code de la démarche administrative (en anglais, « procedure »)', () => {
    const requeteJustificatif = new RequeteJustificatif(
      configurationRequete,
      { codeDemarche: 'T3' },
    );
    const xml = parseXML(requeteJustificatif.corpsMessageEnXML());

    const codeDemarche = valeurSlot('Procedure', xml.QueryRequest);
    expect(codeDemarche.LocalizedString['@_value']).toBe('T3');
  });
});
