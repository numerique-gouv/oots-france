const ConstructeurEnveloppeSOAPAvecPieceJointe = require('../constructeurs/constructeurEnveloppeSOAPAvecPieceJointe');
const InstructionSOAP = require('../../src/domibus/instructionSOAP');
const ReponseEnvoiMessage = require('../../src/domibus/reponseEnvoiMessage');
const ReponseRecuperationMessage = require('../../src/domibus/reponseRecuperationMessage');
const ReponseRequeteListeMessagesEnAttente = require('../../src/domibus/reponseRequeteListeMessagesEnAttente');
const { ErreurInstructionSOAPInconnue } = require('../../src/erreurs');

describe('Une instruction SOAP', () => {
  it("génère une `ErreurInstructionSOAPInconnue` si l'instruction est inconnue", (suite) => {
    expect(InstructionSOAP.instructionsExistantes()).not.toContain('instructionInconnue');

    try {
      new InstructionSOAP('instructionInconnue', {});
      suite("L'instanciation d'une instruction inconnue aurait dû générer une `ErreurInstructionSOAPInconnue`");
    } catch (e) {
      expect(e).toBeInstanceOf(ErreurInstructionSOAPInconnue);
      expect(e.message).toBe('Instruction SOAP inconnue: instructionInconnue');
      suite();
    }
  });

  describe('envoi de message', () => {
    it('génère une `ReponseEnvoiMessage`', () => {
      const instruction = InstructionSOAP.envoieMessage();
      const donnees = {};
      expect(instruction.nouvelleReponseDomibus(donnees)).toBeInstanceOf(ReponseEnvoiMessage);
    });
  });

  describe('liste des messages en attentes', () => {
    it('génère une `ReponseRequeteListeMessagesEnAttente`', () => {
      const instruction = InstructionSOAP.listeMessagesEnAttente();
      const donnees = {};
      expect(instruction.nouvelleReponseDomibus(donnees))
        .toBeInstanceOf(ReponseRequeteListeMessagesEnAttente);
    });
  });

  describe("recupération d'un message", () => {
    it('génère une `ReponseRecuperationMessage`', () => {
      const instruction = InstructionSOAP.recupereMessage();
      const donnees = new ConstructeurEnveloppeSOAPAvecPieceJointe().construis();
      expect(instruction.nouvelleReponseDomibus(donnees))
        .toBeInstanceOf(ReponseRecuperationMessage);
    });
  });
});
