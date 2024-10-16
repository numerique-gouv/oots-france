const { parseXML, valeurSlot, verifiePresenceSlot } = require('../../src/ebms/utils');
const ReponseVerificationSysteme = require('../../src/ebms/reponseVerificationSysteme');
const PointAcces = require('../../src/ebms/pointAcces');

describe('Reponse Verification Systeme', () => {
  const adaptateurUUID = {};
  const horodateur = {};
  const config = { adaptateurUUID, horodateur };
  const donnees = { destinataire: new PointAcces('unTypeIdentifiant', 'unIdentifiant') };

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => '';
    horodateur.maintenant = () => '';
  });

  it('contient la description des méta-données de la pièce justificative', () => {
    const reponse = new ReponseVerificationSysteme(config, donnees);
    const xml = parseXML(reponse.corpsMessageEnXML());

    const scopeRecherche = xml.QueryResponse.RegistryObjectList.RegistryObject;
    verifiePresenceSlot('EvidenceMetadata', scopeRecherche);

    const evidence = valeurSlot('EvidenceMetadata', scopeRecherche).Evidence;
    expect(evidence).toBeDefined();
    expect(evidence.Identifier).toBeDefined();
    expect(evidence.IsAbout).toBeDefined();
    expect(evidence.IsAbout.NaturalPerson).toBeDefined();
    expect(evidence.IsAbout.NaturalPerson.Identifier).toBeDefined(); // /!\
    expect(evidence.IsAbout.NaturalPerson.Identifier['@_schemeID']).toBe('eidas');
    expect(evidence.IsAbout.NaturalPerson.FamilyName).toBeDefined();
    expect(evidence.IsAbout.NaturalPerson.GivenName).toBeDefined();
    expect(evidence.IsAbout.NaturalPerson.DateOfBirth).toBeDefined();
    expect(evidence.IssuingAuthority).toBeDefined();
    expect(evidence.IssuingAuthority.Identifier).toBeDefined(); // /!\
    expect(evidence.IssuingAuthority.Identifier['@_schemeID']).toBe('urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR');
    expect(evidence.IssuingAuthority.Name).toBeDefined();
    expect(evidence.IsConformantTo).toBeDefined();
    expect(evidence.IsConformantTo.EvidenceTypeClassification).toBeDefined();
    expect(evidence.IsConformantTo.Title).toBeDefined();
    expect(evidence.IsConformantTo.Title['@_lang']).toBe('EN');
    expect(evidence.IssuingDate).toBeDefined();
    expect(evidence.Distribution).toBeDefined();
  });

  it("contient la description d'un fournisseur de pièces justificatives", () => {
    const reponse = new ReponseVerificationSysteme(config, donnees);
    const xml = parseXML(reponse.corpsMessageEnXML());

    const scopeRecherche = xml.QueryResponse;
    verifiePresenceSlot('EvidenceProvider', scopeRecherche);

    const fournisseur = valeurSlot('EvidenceProvider', scopeRecherche).Agent;
    expect(fournisseur).toBeDefined();
    expect(fournisseur.Identifier).toBeDefined();
    expect(fournisseur.Identifier['@_schemeID']).toBe('urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR');
    expect(fournisseur.Name).toBeDefined();
    expect(fournisseur.Classification).toBeDefined();
    expect(fournisseur.Classification).toBe('EP');
  });

  it('contient la description du requêteur de la pièce justificative', () => {
    const reponse = new ReponseVerificationSysteme(config, donnees);
    const xml = parseXML(reponse.corpsMessageEnXML());

    const scopeRecherche = xml.QueryResponse;
    verifiePresenceSlot('EvidenceRequester', scopeRecherche);

    const requeteur = valeurSlot('EvidenceRequester', scopeRecherche).Agent;
    expect(requeteur).toBeDefined();
    expect(requeteur.Identifier).toBeDefined();
    expect(requeteur.Identifier['@_schemeID']).toBeDefined(); // /!\
    expect(requeteur.Name).toBeDefined();
  });

  it('injecte un identifiant unique de pièce justificative', () => {
    adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';
    const reponse = new ReponseVerificationSysteme(config, donnees);
    const xml = parseXML(reponse.corpsMessageEnXML());
    const scopeRecherche = xml.QueryResponse.RegistryObjectList.RegistryObject;

    const idPiece = valeurSlot('EvidenceMetadata', scopeRecherche).Evidence.Identifier;
    expect(idPiece).toEqual('11111111-1111-1111-1111-111111111111');
  });

  it('contient une pièce jointe', () => {
    adaptateurUUID.genereUUID = () => '12345678-abcd-abcd-abcd-123456789012';
    const reponse = new ReponseVerificationSysteme(config, donnees);

    expect(reponse.corpsMessageEnXML()).toContain('RepositoryItemRef xlink:href="cid:12345678-abcd-abcd-abcd-123456789012@pdf.oots.fr"');
  });
});
