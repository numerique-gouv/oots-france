const { parseXML, verifiePresenceSlot, valeurSlot } = require('../../src/ebms/utils');
const Fournisseur = require('../../src/ebms/fournisseur');
const PersonnePhysique = require('../../src/ebms/personnePhysique');
const RequeteJustificatif = require('../../src/ebms/requeteJustificatif');
const TypeJustificatif = require('../../src/ebms/typeJustificatif');

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

  it("injecte l'identifiant de type de justificatif demandé", () => {
    const requeteJustificatif = new RequeteJustificatif(
      configurationRequete,
      { typeJustificatif: new TypeJustificatif({ id: 'unIdentifiant' }) },
    );
    const xml = parseXML(requeteJustificatif.corpsMessageEnXML());

    const requete = valeurSlot('EvidenceRequest', xml.QueryRequest.Query);
    expect(requete.DataServiceEvidenceType.EvidenceTypeClassification).toBe('unIdentifiant');
  });

  it('injecte le fournisseur', () => {
    const requeteJustificatif = new RequeteJustificatif(
      configurationRequete,
      { fournisseur: new Fournisseur({ pointAcces: { typeId: 'unType', id: 'unIdentifiant' } }) },
    );
    const xml = parseXML(requeteJustificatif.corpsMessageEnXML());

    const fournisseur = valeurSlot('EvidenceProvider', xml.QueryRequest);
    expect(fournisseur.Agent.Identifier['#text']).toBe('unIdentifiant');
  });

  it('injecte les données du bénéficiaire', () => {
    const requeteJustificatif = new RequeteJustificatif(
      configurationRequete,
      { beneficiaire: new PersonnePhysique({ nom: 'Durand', prenom: 'Sabine', dateNaissance: '1987-03-28' }) },
    );
    const xml = parseXML(requeteJustificatif.corpsMessageEnXML());
    const naturalPerson = valeurSlot('NaturalPerson', xml.QueryRequest.Query);
    expect(naturalPerson.Person.FamilyName).toBe('Durand');
    expect(naturalPerson.Person.GivenName).toBe('Sabine');
    expect(naturalPerson.Person.DateOfBirth).toBe('1987-03-28');
  });
});
