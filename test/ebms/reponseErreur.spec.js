const { parseXML, verifiePresenceSlot, valeurSlot } = require('./utils');
const ReponseErreur = require('../../src/ebms/reponseErreur');

describe('Une réponse EBMS en erreur', () => {
  const horodateur = {};
  const adaptateurUUID = {};

  beforeEach(() => {
    horodateur.maintenant = () => '';
    adaptateurUUID.genereUUID = () => '';
  });

  it("injecte l'identifiant unique de requête", () => {
    const reponse = new ReponseErreur({ idRequete: '11111111-1111-1111-1111-111111111111' });

    const xml = parseXML(reponse.enXML());
    const idRequete = xml.QueryResponse['@_requestId'];
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

    const xml = parseXML(reponse.enXML());
    const sectionException = xml.QueryResponse.Exception;
    expect(sectionException).toBeDefined();
    expect(sectionException['@_type']).toEqual('unType');
    expect(sectionException['@_message']).toEqual('Un message');
    expect(sectionException['@_severity']).toEqual('unCodeSeverite');
    expect(sectionException['@_code']).toEqual('unCodeException');
  });

  describe('dans la section `Exception`', () => {
    it('est horodatée', () => {
      horodateur.maintenant = () => '2023-09-30T14:30:00.000Z';
      const reponse = new ReponseErreur({}, { horodateur });

      const xml = parseXML(reponse.enXML());
      const horodatage = valeurSlot('Timestamp', xml.QueryResponse.Exception);
      expect(horodatage).toEqual('2023-09-30T14:30:00.000Z');
    });
  });

  it('contient une section `SpecificationIdentifier`', () => {
    const reponse = new ReponseErreur();
    const xml = parseXML(reponse.enXML());
    verifiePresenceSlot('SpecificationIdentifier', xml.QueryResponse);
  });

  describe('dans la section `EvidenceResponseIdentifier`', () => {
    it('est identifiée par un UUID', () => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      const reponse = new ReponseErreur({}, { adaptateurUUID });
      const xml = parseXML(reponse.enXML());

      const idReponse = valeurSlot('EvidenceResponseIdentifier', xml.QueryResponse);
      expect(idReponse).toEqual('11111111-1111-1111-1111-111111111111');
    });
  });

  it('contient une section `ErrorProvider`', () => {
    const reponse = new ReponseErreur();
    const xml = parseXML(reponse.enXML());
    verifiePresenceSlot('ErrorProvider', xml.QueryResponse);
  });
});
