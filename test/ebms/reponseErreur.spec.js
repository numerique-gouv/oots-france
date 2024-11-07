const { parseXML, verifiePresenceSlot, valeurSlot } = require('../../src/ebms/utils');
const ReponseErreur = require('../../src/ebms/reponseErreur');

describe('Une réponse EBMS en erreur', () => {
  const adaptateurUUID = {};
  const horodateur = {};
  const config = { adaptateurUUID, horodateur };

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => '';
    horodateur.maintenant = () => '';
  });

  it("injecte l'identifiant unique de requête", () => {
    const reponse = new ReponseErreur(config, { idRequete: 'urn:uuid:11111111-1111-1111-1111-111111111111' });

    const xml = parseXML(reponse.corpsMessageEnXML());
    const idRequete = xml.QueryResponse['@_requestId'];
    expect(idRequete).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111');
  });

  it('contient une section `Exception`', () => {
    const reponse = new ReponseErreur(config, {
      exception: {
        type: 'unType',
        message: 'Un message',
        severite: 'unCodeSeverite',
        code: 'unCodeException',
      },
    });

    const xml = parseXML(reponse.corpsMessageEnXML());
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
      const reponse = new ReponseErreur(config, {});

      const xml = parseXML(reponse.corpsMessageEnXML());
      const horodatage = valeurSlot('Timestamp', xml.QueryResponse.Exception);
      expect(horodatage).toEqual('2023-09-30T14:30:00.000Z');
    });
  });

  it('contient une section `SpecificationIdentifier`', () => {
    const reponse = new ReponseErreur(config);
    const xml = parseXML(reponse.corpsMessageEnXML());
    verifiePresenceSlot('SpecificationIdentifier', xml.QueryResponse);
  });

  describe('dans la section `EvidenceResponseIdentifier`', () => {
    it('est identifiée par un UUID', () => {
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      const reponse = new ReponseErreur(config);
      const xml = parseXML(reponse.corpsMessageEnXML());

      const idReponse = valeurSlot('EvidenceResponseIdentifier', xml.QueryResponse);
      expect(idReponse).toEqual('11111111-1111-1111-1111-111111111111');
    });
  });

  it('contient une section `ErrorProvider`', () => {
    const reponse = new ReponseErreur(config);
    const xml = parseXML(reponse.corpsMessageEnXML());
    verifiePresenceSlot('ErrorProvider', xml.QueryResponse);
  });
});
