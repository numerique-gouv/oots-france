const ConstructeurEnveloppeSOAPAvecPieceJointe = require('../constructeurs/constructeurEnveloppeSOAPAvecPieceJointe');
const ConstructeurEnveloppeSOAPException = require('../constructeurs/constructeurEnveloppeSOAPException');
const ConstructeurEnveloppeSOAPRequete = require('../constructeurs/constructeurEnveloppeSOAPRequete');
const ReponseErreurAutorisationRequise = require('../../src/domibus/reponseErreurAutorisationRequise');
const ReponseRecuperationMessage = require('../../src/domibus/reponseRecuperationMessage');
const CodeDemarche = require('../../src/ebms/codeDemarche');
const PointAcces = require('../../src/ebms/pointAcces');
const { ErreurReponseRequete } = require('../../src/erreurs');

describe('La réponse à une requête Domibus de récupération de message', () => {
  it("connaît l'URL de redirection spécifiée", () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecURLRedirection('https://example.com/preview/12345678-1234-1234-1234-1234567890ab')
      .construis();
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP);

    expect(reponse.corpsMessage).toBeInstanceOf(ReponseErreurAutorisationRequise);
    expect(reponse.suiteConversation()).toEqual('https://example.com/preview/12345678-1234-1234-1234-1234567890ab');
  });

  it("connaît le type d'action liée au message", () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .construis();
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP);

    expect(reponse.action()).toEqual('ExceptionResponse');
  });

  it("connaît l'identifiant de la conversation", () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecIdConversation('12345678-1234-1234-1234-1234567890ab')
      .construis();
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP);

    expect(reponse.idConversation()).toEqual('12345678-1234-1234-1234-1234567890ab');
  });

  it("connaît l'expéditeur", () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecExpediteur(new PointAcces('unIdentifiant', 'unType'))
      .construis();
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP);

    expect(reponse.expediteur().id).toEqual('unIdentifiant');
    expect(reponse.expediteur().typeId).toEqual('unType');
  });

  it('connaît son identifiant de message', () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecIdMessage('11111111-1111-1111-1111-111111111111@oots.eu')
      .construis();
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP);

    expect(reponse.idMessage()).toEqual('11111111-1111-1111-1111-111111111111@oots.eu');
  });

  it('connaît son identifiant de payload du message EBMS', () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecIdPayload('cid:11111111-1111-1111-1111-111111111111@oots.eu')
      .construis();

    const reponse = new ReponseRecuperationMessage(enveloppeSOAP);
    expect(reponse.idsPayloads['application/x-ebrs+xml']).toEqual('cid:11111111-1111-1111-1111-111111111111@oots.eu');
  });

  it('sait extraire une pièce jointe', () => {
    const enveloppeSOAP = new ConstructeurEnveloppeSOAPAvecPieceJointe()
      .avecPieceJointe('cid:12345678-1234-1234-1234-1234567890ab@pdf.oots.eu', 'application/pdf', 'abcd')
      .construis();

    const reponse = new ReponseRecuperationMessage(enveloppeSOAP);
    const contenuPieceJustificative = reponse.pieceJustificative().toString();
    expect(contenuPieceJustificative).toEqual('abcd');
  });

  describe("dans le cas d'une réponse en erreur pièce inexistante", () => {
    it("lève une erreur à la tentative de lecture de l'URL de redirection", (suite) => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPException()
        .avecErreur({
          type: 'rs:ObjectNotFoundExceptionType',
          code: 'EDM:ERR:0004',
          message: 'Object not found',
          severite: 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error',
        })
        .construis();
      const reponse = new ReponseRecuperationMessage(enveloppeSOAP);

      try {
        reponse.suiteConversation();
        suite('Une `ErreurReponseRequete` aurait dû être levée.');
      } catch (e) {
        expect(e).toBeInstanceOf(ErreurReponseRequete);
        expect(e.message).toEqual('Object not found');
        suite();
      }
    });
  });

  describe("dans le cas d'une requête de pièce justificative", () => {
    it('connaît le code de la démarche', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis();

      const reponse = new ReponseRecuperationMessage(enveloppeSOAP);
      expect(reponse.codeDemarche()).toBe(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE);
    });
  });
});
