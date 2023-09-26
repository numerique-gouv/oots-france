const { XMLParser } = require('fast-xml-parser');

const entete = require('../../src/ebms/entete');

describe("l'entête EBMS", () => {
  const parser = new XMLParser({ ignoreAttributes: false });
  const adaptateurUUID = {};
  const horodateur = {};
  let suffixe;

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => '';
    horodateur.maintenant = () => '';
    suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS;
  });

  afterEach(() => {
    process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS = suffixe;
  });

  it('suit la structure EMBS', () => {
    const enteteEBMS = entete({ adaptateurUUID, horodateur });
    const xml = parser.parse(enteteEBMS);

    expect(xml['eb:Messaging']['eb:UserMessage']['eb:MessageInfo']).toBeDefined();
    expect(xml['eb:Messaging']['eb:UserMessage']['eb:PartyInfo']).toBeDefined();
    expect(xml['eb:Messaging']['eb:UserMessage']['eb:CollaborationInfo']).toBeDefined();
    expect(xml['eb:Messaging']['eb:UserMessage']['eb:MessageProperties']).toBeDefined();
    expect(xml['eb:Messaging']['eb:UserMessage']['eb:PayloadInfo']).toBeDefined();
  });

  describe('dans le chemin /eb:Messaging/eb:UserMessage/eb:MessageInfo', () => {
    it('est horodaté', () => {
      horodateur.maintenant = () => '2023-09-01T15:30:00.000Z';
      const enteteEBMS = entete({ adaptateurUUID, horodateur });
      const xml = parser.parse(enteteEBMS);
      const horodatage = xml['eb:Messaging']['eb:UserMessage']['eb:MessageInfo']['eb:Timestamp'];

      expect(horodatage).toEqual('2023-09-01T15:30:00.000Z');
    });

    it('est identifié', () => {
      process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS = 'oots.eu';
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      const enteteEBMS = entete({ adaptateurUUID, horodateur });
      const xml = parser.parse(enteteEBMS);
      const idMessage = xml['eb:Messaging']['eb:UserMessage']['eb:MessageInfo']['eb:MessageId'];

      expect(idMessage).toEqual('11111111-1111-1111-1111-111111111111@oots.eu');
    });
  });

  describe('dans le chemin /eb:Messaging/eb:UserMessage/eb:MessageProperties', () => {
    it("renseigne l'expéditeur (C1)", () => {
      const enteteEBMS = entete({ adaptateurUUID, horodateur });
      const xml = parser.parse(enteteEBMS);
      const proprietes = xml['eb:Messaging']['eb:UserMessage']['eb:MessageProperties']['eb:Property'];
      const expediteur = proprietes.find((p) => p['@_name'] === 'originalSender');

      expect(expediteur['@_type']).toEqual('urn:oasis:names:tc:ebcore:partyid-type:unregistered');
      expect(expediteur['#text']).toEqual('C1');
    });

    it('renseigne le destinataire final (C4)', () => {
      const enteteEBMS = entete({ adaptateurUUID, horodateur });
      const xml = parser.parse(enteteEBMS);
      const proprietes = xml['eb:Messaging']['eb:UserMessage']['eb:MessageProperties']['eb:Property'];
      const expediteur = proprietes.find((p) => p['@_name'] === 'finalRecipient');

      expect(expediteur['@_type']).toEqual('urn:oasis:names:tc:ebcore:partyid-type:unregistered');
      expect(expediteur['#text']).toEqual('C4');
    });
  });

  describe('dans le chemin /eb:Messaging/eb:UserMessage/eb:PayloadInfo', () => {
    it('identifie le payload du message', () => {
      const enteteEBMS = entete(
        { adaptateurUUID, horodateur },
        { idPayload: 'cid:11111111-1111-1111-1111-111111111111@oots.eu' },
      );
      const xml = parser.parse(enteteEBMS);
      const idPayload = xml['eb:Messaging']['eb:UserMessage']['eb:PayloadInfo']['eb:PartInfo']['@_href'];

      expect(idPayload).toEqual('cid:11111111-1111-1111-1111-111111111111@oots.eu');
    });
  });
});
