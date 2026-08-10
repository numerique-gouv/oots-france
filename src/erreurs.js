class ErreurAbsenceReponseDestinataire extends Error {}
class ErreurAucunMessageDomibusRecu extends Error {}
class ErreurConfiguration extends Error {}
class ErreurEchecAuthentification extends Error {}
class ErreurInstructionSOAPInconnue extends Error {}
class ErreurJetonInvalide extends Error {}
class ErreurReponseRequete extends Error {}
// Un message reçu dont une donnée attendue manque — slot absent, ou présent
// mais vide de ce qu'on y cherche. Classe plate
// et non sous-classe d'`ErreurEBMS` : celle-ci pilote le 422 rendu au
// fournisseur de service, or un message étranger malformé n'est pas une faute
// de son appelant.
class ErreurMessageIllisible extends Error {}

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
  ErreurConfiguration,
  ErreurDestinataireInexistant,
  ErreurEchecAuthentification,
  ErreurEBMS,
  ErreurInstructionSOAPInconnue,
  ErreurJetonInvalide,
  ErreurReponseRequete,
  ErreurRequeteurInexistant,
  ErreurMessageIllisible,
  ErreurTypeJustificatifIntrouvable,
}
