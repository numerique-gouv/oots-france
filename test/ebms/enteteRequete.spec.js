const { parseXML } = require('./utils');
const EnteteRequete = require('../../src/ebms/enteteRequete');

describe("l'entête EBMS de requête", () => {
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
    const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur });
    const xml = parseXML(enteteEBMS.enXML());
    const userMessageInfos = xml.Messaging.UserMessage;

    expect(userMessageInfos.MessageInfo).toBeDefined();
    expect(userMessageInfos.PartyInfo).toBeDefined();
    expect(userMessageInfos.CollaborationInfo).toBeDefined();
    expect(userMessageInfos.MessageProperties).toBeDefined();
    expect(userMessageInfos.PayloadInfo).toBeDefined();
  });

  describe('dans le chemin /Messaging/UserMessage/MessageInfo', () => {
    it('est horodaté', () => {
      horodateur.maintenant = () => '2023-09-01T15:30:00.000Z';
      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur });
      const xml = parseXML(enteteEBMS.enXML());
      const horodatage = xml.Messaging.UserMessage.MessageInfo.Timestamp;

      expect(horodatage).toEqual('2023-09-01T15:30:00.000Z');
    });

    it('est identifié', () => {
      process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS = 'oots.eu';
      adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111';

      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur });
      const xml = parseXML(enteteEBMS.enXML());
      const idMessage = xml.Messaging.UserMessage.MessageInfo.MessageId;

      expect(idMessage).toEqual('11111111-1111-1111-1111-111111111111@oots.eu');
    });
  });

  describe('dans le chemin /Messaging/UserMessage/PartyInfo', () => {
    let identifiantExpediteur;
    let typeIdentifiantExpediteur;

    beforeEach(() => {
      identifiantExpediteur = process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS;
      typeIdentifiantExpediteur = process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS;
    });

    afterEach(() => {
      process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS = identifiantExpediteur;
      process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS = typeIdentifiantExpediteur;
    });

    it("renseigne l'expéditeur (C2)", () => {
      process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS = 'unIdentifiant';
      process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS = 'unType';

      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur });
      const xml = parseXML(enteteEBMS.enXML());
      const expediteur = xml.Messaging.UserMessage.PartyInfo.From.PartyId;

      expect(expediteur['@_type']).toBe('unType');
      expect(expediteur['#text']).toBe('unIdentifiant');
    });

    it('renseigne le destinataire (C3)', () => {
      const enteteEBMS = new EnteteRequete(
        { adaptateurUUID, horodateur },
        { destinataire: { typeIdentifiant: 'unType', id: 'unIdentifiant' } },
      );
      const xml = parseXML(enteteEBMS.enXML());
      const destinataire = xml.Messaging.UserMessage.PartyInfo.To.PartyId;

      expect(destinataire['@_type']).toBe('unType');
      expect(destinataire['#text']).toBe('unIdentifiant');
    });
  });

  describe('dans le chemin /Messaging/UserMessage/MessageProperties', () => {
    it("renseigne l'expéditeur (C1)", () => {
      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur });
      const xml = parseXML(enteteEBMS.enXML());
      const proprietes = xml.Messaging.UserMessage.MessageProperties.Property;
      const expediteur = proprietes.find((p) => p['@_name'] === 'originalSender');

      expect(expediteur['@_type']).toEqual('urn:oasis:names:tc:ebcore:partyid-type:unregistered');
      expect(expediteur['#text']).toEqual('C1');
    });

    it('renseigne le destinataire final (C4)', () => {
      const enteteEBMS = new EnteteRequete({ adaptateurUUID, horodateur });
      const xml = parseXML(enteteEBMS.enXML());
      const proprietes = xml.Messaging.UserMessage.MessageProperties.Property;
      const expediteur = proprietes.find((p) => p['@_name'] === 'finalRecipient');

      expect(expediteur['@_type']).toEqual('urn:oasis:names:tc:ebcore:partyid-type:unregistered');
      expect(expediteur['#text']).toEqual('C4');
    });
  });

  describe('dans le chemin /Messaging/UserMessage/PayloadInfo', () => {
    it('identifie le payload du message', () => {
      const enteteEBMS = new EnteteRequete(
        { adaptateurUUID, horodateur },
        { idPayload: 'cid:11111111-1111-1111-1111-111111111111@oots.eu' },
      );
      const xml = parseXML(enteteEBMS.enXML());
      const idPayload = xml.Messaging.UserMessage.PayloadInfo.PartInfo['@_href'];

      expect(idPayload).toEqual('cid:11111111-1111-1111-1111-111111111111@oots.eu');
    });
  });
});
