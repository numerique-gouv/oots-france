class ErreurAbsenceReponseDestinataire extends Error {}
class ErreurAucunMessageDomibusRecu extends Error {}
class ErreurEchecAuthentification extends Error {}
class ErreurInstructionSOAPInconnue extends Error {}
class ErreurJetonInvalide extends Error {}
class ErreurReponseRequete extends Error {}

class ErreurEBMS extends Error {}
class ErreurCodeDemarcheIntrouvable extends ErreurEBMS {}
class ErreurCodePaysIntrouvable extends ErreurEBMS {}
class ErreurDestinataireInexistant extends ErreurEBMS {}
class ErreurRequeteurInexistant extends ErreurEBMS {}
class ErreurTypeJustificatifIntrouvable extends ErreurEBMS {}

module.exports = {
  ErreurAbsenceReponseDestinataire,
  ErreurAucunMessageDomibusRecu,
  ErreurCodeDemarcheIntrouvable,
  ErreurCodePaysIntrouvable,
  ErreurDestinataireInexistant,
  ErreurEchecAuthentification,
  ErreurEBMS,
  ErreurInstructionSOAPInconnue,
  ErreurJetonInvalide,
  ErreurReponseRequete,
  ErreurRequeteurInexistant,
  ErreurTypeJustificatifIntrouvable,
};
