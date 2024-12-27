class ErreurAbsenceReponseDestinataire extends Error {}
class ErreurAucunMessageDomibusRecu extends Error {}
class ErreurEchecAuthentification extends Error {}
class ErreurInstructionSOAPInconnue extends Error {}
class ErreurReponseRequete extends Error {}

class ErreurDomibus extends Error {}
class ErreurAttributInconnu extends ErreurDomibus {}

class ErreurEBMS extends Error {}
class ErreurCodeDemarcheIntrouvable extends ErreurEBMS {}
class ErreurCodePaysIntrouvable extends ErreurEBMS {}
class ErreurDestinataireInexistant extends ErreurEBMS {}
class ErreurRequeteurInexistant extends ErreurEBMS {}
class ErreurTypeJustificatifIntrouvable extends ErreurEBMS {}

module.exports = {
  ErreurAbsenceReponseDestinataire,
  ErreurAttributInconnu,
  ErreurAucunMessageDomibusRecu,
  ErreurCodeDemarcheIntrouvable,
  ErreurCodePaysIntrouvable,
  ErreurDestinataireInexistant,
  ErreurEchecAuthentification,
  ErreurEBMS,
  ErreurInstructionSOAPInconnue,
  ErreurReponseRequete,
  ErreurRequeteurInexistant,
  ErreurTypeJustificatifIntrouvable,
};
