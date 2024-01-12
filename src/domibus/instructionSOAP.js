const ReponseEnvoiMessage = require('./reponseEnvoiMessage');
const ReponseRecuperationMessage = require('./reponseRecuperationMessage');
const ReponseRequeteListeMessagesEnAttente = require('./reponseRequeteListeMessagesEnAttente');
const { ErreurInstructionSOAPInconnue } = require('../erreurs');

const instructions = {
  ENVOIE_MESSAGE: {
    libelle: 'submitMessage',
    classeReponse: ReponseEnvoiMessage,
  },
  LISTE_MESSAGES_EN_ATTENTE: {
    libelle: 'listPendingMessages',
    classeReponse: ReponseRequeteListeMessagesEnAttente,
  },
  RECUPERE_MESSAGE: {
    libelle: 'retrieveMessage',
    classeReponse: ReponseRecuperationMessage,
  },
};

const libelles = Object.keys(instructions)
  .reduce((acc, cle) => ({ ...acc, [cle]: instructions[cle].libelle }), {});

class InstructionSOAP {
  static instructionsExistantes() {
    return Object.values(libelles);
  }

  static envoieMessage() {
    return new InstructionSOAP('submitMessage');
  }

  static listeMessagesEnAttente() {
    return new InstructionSOAP('listPendingMessages');
  }

  static recupereMessage() {
    return new InstructionSOAP('retrieveMessage');
  }

  constructor(libelleInstruction) {
    if (!InstructionSOAP.instructionsExistantes().includes(libelleInstruction)) {
      throw new ErreurInstructionSOAPInconnue(`Instruction SOAP inconnue: ${libelleInstruction}`);
    }

    this.libelle = libelleInstruction;
    this.ClasseReponse = Object.values(instructions)
      .find(({ libelle }) => libelle === libelleInstruction)
      .classeReponse;
  }

  nouvelleReponseDomibus(data) {
    return new this.ClasseReponse(data);
  }
}

Object.assign(InstructionSOAP, libelles);
module.exports = InstructionSOAP;
