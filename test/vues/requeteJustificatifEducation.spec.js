const { XMLParser } = require('fast-xml-parser');

const RequeteJustificatifEducation = require('../../src/vues/requeteJustificatifEducation');

describe("La vue du message de requête d'un justificatif", () => {
  const parser = new XMLParser({ ignoreAttributes: false });

  it('injecte un identifiant unique de requête', () => {
    const requeteJustificatif = new RequeteJustificatifEducation('11111111-1111-1111-1111-111111111111');

    const xml = parser.parse(requeteJustificatif.enXML());
    const requestId = xml['query:QueryRequest']['@_id'];
    expect(requestId).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
  });

  it('respecte la structure définie par OOTS', () => {
    const requeteJustificatif = new RequeteJustificatifEducation('11111111-1111-1111-1111-111111111111');
    const xml = parser.parse(requeteJustificatif.enXML());

    expect(xml['query:QueryRequest']['rim:Slot']).toBeDefined();
    const slots = [].concat(xml['query:QueryRequest']['rim:Slot']);
    expect(slots.some((s) => s['@_name'] === 'SpecificationIdentifier')).toBe(true);
    expect(slots.some((s) => s['@_name'] === 'IssueDateTime')).toBe(true);
    expect(slots.some((s) => s['@_name'] === 'Procedure')).toBe(true);
    expect(slots.some((s) => s['@_name'] === 'PossibilityForPreview')).toBe(true);
    expect(slots.some((s) => s['@_name'] === 'ExplicitRequestGiven')).toBe(true);
    expect(slots.some((s) => s['@_name'] === 'Requirements')).toBe(true);
    expect(slots.some((s) => s['@_name'] === 'EvidenceRequester')).toBe(true);
    expect(slots.some((s) => s['@_name'] === 'EvidenceProvider')).toBe(true);

    expect(xml['query:QueryRequest']['query:Query']['rim:Slot']).toBeDefined();
    const querySlots = [].concat(xml['query:QueryRequest']['query:Query']['rim:Slot']);
    expect(querySlots.some((s) => s['@_name'] === 'EvidenceRequest')).toBe(true);
    expect(querySlots.some((s) => s['@_name'] === 'NaturalPerson')).toBe(true);

    expect(xml['query:QueryRequest']['query:ResponseOption']).toBeDefined();
    expect(xml['query:QueryRequest']['query:ResponseOption']['@_returnType']).toEqual('LeafClassWithRepositoryItem');

    expect(xml['query:QueryRequest']['query:Query']).toBeDefined();
    expect(xml['query:QueryRequest']['query:Query']['@_queryDefinition']).toEqual('DocumentQuery');
  });
});
