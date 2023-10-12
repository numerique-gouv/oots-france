const { XMLParser } = require('fast-xml-parser');

const ReponseErreur = require('../../src/ebms/reponseErreur');

const verifiePresenceSlotAvecNom = (nomSlot, scopeRecherche) => {
  expect(scopeRecherche).toBeDefined();

  const sectionSlots = scopeRecherche['rim:Slot'];
  expect(sectionSlots).toBeDefined();

  const slots = [].concat(sectionSlots);
  expect(slots.some((s) => s['@_name'] === nomSlot)).toBe(true);
};

const valeurSlot = (nomSlot, scopeRecherche) => {
  verifiePresenceSlotAvecNom(nomSlot, scopeRecherche);
  const sectionSlots = scopeRecherche['rim:Slot'];
  const slots = [].concat(sectionSlots);
  return slots.find((s) => s['@_name'] === nomSlot)['rim:SlotValue']['rim:Value'];
};

describe('Une réponse EBMS en erreur', () => {
  const parser = new XMLParser({ ignoreAttributes: false });
  const horodateur = {};
  const adaptateurUUID = {};

  beforeEach(() => {
    horodateur.maintenant = () => '';
    adaptateurUUID.genereUUID = () => '';
  });

  it("injecte l'identifiant unique de requête", () => {
    const reponse = new ReponseErreur({ idRequete: '11111111-1111-1111-1111-111111111111' });

    const xml = parser.parse(reponse.enXML());
    const idRequete = xml['query:QueryResponse']['@_requestId'];
    expect(idRequete).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
  });

  it('contient une section `Exception`', () => {
    const reponse = new ReponseErreur({
      exception: {
        type: 'unType',
        message: 'Un message',
        severite: 'unCodeSeverite',
        code: 'unCodeException',
      },
    });

    const xml = parser.parse(reponse.enXML());
    const sectionException = xml['query:QueryResponse']['rs:Exception'];
    expect(sectionException).toBeDefined();
    expect(sectionException['@_xsi:type']).toEqual('unType');
    expect(sectionException['@_message']).toEqual('Un message');
    expect(sectionException['@_severity']).toEqual('unCodeSeverite');
    expect(sectionException['@_code']).toEqual('unCodeException');
  });

  describe('dans la section `Exception`', () => {
    it('est horodatée', () => {
      horodateur.maintenant = () => '2023-09-30T14:30:00.000Z';
      const reponse = new ReponseErreur({}, { horodateur });

      const xml = parser.parse(reponse.enXML());
      const horodatage = valeurSlot('Timestamp', xml['query:QueryResponse']['rs:Exception']);
      expect(horodatage).toEqual('2023-09-30T14:30:00.000Z');
    });
  });

  it('contient une section `SpecificationIdentifier`', () => {
    const reponse = new ReponseErreur();
    const xml = parser.parse(reponse.enXML());
    verifiePresenceSlotAvecNom('SpecificationIdentifier', xml['query:QueryResponse']);
  });

  describe('dans la section `EvidenceResponseIdentifier`', () => {
    it('est identifiée par un UUID', () => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      const reponse = new ReponseErreur({}, { adaptateurUUID });
      const xml = parser.parse(reponse.enXML());

      const idReponse = valeurSlot('EvidenceResponseIdentifier', xml['query:QueryResponse']);
      expect(idReponse).toEqual('11111111-1111-1111-1111-111111111111');
    });
  });

  it('contient une section `ErrorProvider`', () => {
    const reponse = new ReponseErreur();
    const xml = parser.parse(reponse.enXML());
    verifiePresenceSlotAvecNom('ErrorProvider', xml['query:QueryResponse']);
  });
});
