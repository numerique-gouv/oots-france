const PersonnePhysique = require('../../src/ebms/personnePhysique');
const PointAcces = require('../../src/ebms/pointAcces');
const ReponseVerificationSysteme = require('../../src/ebms/reponseVerificationSysteme');
const Requeteur = require('../../src/ebms/requeteur');
const TypeJustificatif = require('../../src/ebms/typeJustificatif');
const { parseXML, valeurSlot, verifiePresenceSlot } = require('../../src/ebms/utils');

describe('Reponse Verification Systeme', () => {
  const adaptateurUUID = {};
  const horodateur = {};
  const config = { adaptateurUUID, horodateur };

  let donnees = {};

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => '';
    donnees = {
      beneficiaire: new PersonnePhysique(),
      destinataire: new PointAcces('unTypeIdentifiant', 'unIdentifiant'),
      requeteur: { enXMLPourReponse: () => '' },
      typeJustificatif: new TypeJustificatif({ descriptions: { EN: 'Some Evidence Type' } }),
    };
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

    const fournisseur = valeurSlot('EvidenceProvider', scopeRecherche)[0].Agent;
    expect(fournisseur).toBeDefined();
    expect(fournisseur.Identifier).toBeDefined();
    expect(fournisseur.Identifier['@_schemeID']).toBe('urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR');
    expect(fournisseur.Name).toBeDefined();
    expect(fournisseur.Classification).toBeDefined();
    expect(fournisseur.Classification).toBe('EP');
  });

  it('contient la description du requêteur de la pièce justificative', () => {
    donnees.requeteur = new Requeteur({}, { id: 'abcdef', nom: 'Un requêteur' });
    const reponse = new ReponseVerificationSysteme(config, donnees);
    const xml = parseXML(reponse.corpsMessageEnXML());

    const scopeRecherche = xml.QueryResponse;
    verifiePresenceSlot('EvidenceRequester', scopeRecherche);

    const requeteur = valeurSlot('EvidenceRequester', scopeRecherche).Agent;
    expect(requeteur).toBeDefined();
    expect(requeteur.Identifier).toBeDefined();
    expect(requeteur.Identifier['@_schemeID']).toBeDefined(); // /!\
    expect(requeteur.Identifier['#text']).toBe('abcdef');
    expect(requeteur.Name).toBeDefined();
    expect(requeteur.Name['#text']).toBe('Un requêteur');
  });

  it('contient la description du bénéficiaire', () => {
    donnees.beneficiaire = new PersonnePhysique({
      dateNaissance: '1992-10-22',
      identifiantEidas: 'DK/DE/123123123',
      nom: 'Dupont',
      prenom: 'Jean',
    });
    const reponse = new ReponseVerificationSysteme(config, donnees);
    const xml = parseXML(reponse.corpsMessageEnXML());
    const scopeRecherche = xml.QueryResponse.RegistryObjectList.RegistryObject;

    const beneficiaire = valeurSlot('EvidenceMetadata', scopeRecherche).Evidence.IsAbout.NaturalPerson;
    expect(beneficiaire.Identifier['#text']).toBe('DK/DE/123123123');
    expect(beneficiaire.FamilyName).toBe('Dupont');
    expect(beneficiaire.GivenName).toBe('Jean');
    expect(beneficiaire.DateOfBirth).toBe('1992-10-22');
  });

  it('injecte un identifiant unique de pièce justificative', () => {
    adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';
    const reponse = new ReponseVerificationSysteme(config, donnees);
    const xml = parseXML(reponse.corpsMessageEnXML());
    const scopeRecherche = xml.QueryResponse.RegistryObjectList.RegistryObject;

    const idPiece = valeurSlot('EvidenceMetadata', scopeRecherche).Evidence.Identifier;
    expect(idPiece).toEqual('11111111-1111-1111-1111-111111111111');
  });

  it('injecte le type de pièce justificative', () => {
    donnees.typeJustificatif = new TypeJustificatif({ id: 'abcdef' });
    const reponse = new ReponseVerificationSysteme(config, donnees);
    const xml = parseXML(reponse.corpsMessageEnXML());
    const scopeRecherche = xml.QueryResponse.RegistryObjectList.RegistryObject;

    const idTypeJustificatif = valeurSlot('EvidenceMetadata', scopeRecherche).Evidence
      .IsConformantTo
      .EvidenceTypeClassification;
    expect(idTypeJustificatif).toBe('abcdef');
  });

  it('contient une pièce jointe', () => {
    adaptateurUUID.genereUUID = () => '12345678-abcd-abcd-abcd-123456789012';
    const reponse = new ReponseVerificationSysteme(config, donnees);

    expect(reponse.corpsMessageEnXML()).toContain('RepositoryItemRef xlink:href="cid:12345678-abcd-abcd-abcd-123456789012@pdf.oots.fr"');
  });
});
