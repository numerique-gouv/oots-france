const Entete = require('../ebms/entete')

// Consigne au journal le message qui vient d'arriver de la passerelle, quel
// qu'il soit — requête entrante, réponse, erreur.
//
// Cette traduction d'un message ebMS en événement du chapitre 4.8 est du
// métier, pas un effet de bord : elle vit ici, aux côtés du parsage des
// messages reçus, plutôt que dans l'adaptateur qui la déclenche, et se teste
// sans passerelle.
//
// Le justificatif ne quitte jamais la mémoire : seule son empreinte est
// consignée, ce que l'article 17 du règlement (UE) 2022/1463 impose en excluant
// la preuve elle-même des journaux.
const journaliseMessageRecu = (message, config = {}) => {
  const { adaptateurChiffrement, depotJournal, fournisseurFrancais } = config
  const commun = {
    actionEbms: message.action(),
    idConversation: message.idConversation(),
    idMessage: message.idMessage(),
    idEchange: message.idEchange(),
  }

  if (message.action() === Entete.REPONSE_ERREUR) {
    return depotJournal.consigneErreurRecue({ ...commun, codeErreur: message.codeErreur() })
  }

  // Les identités des deux autorités ne sont pas redites ici : la réponse close
  // une conversation dont `requete_emise` les porte déjà, sous le même
  // `ConversationId`. Les relire imposerait de parser un slot de plus à chaque
  // message reçu, donc un mode d'échec de plus dans le cycle de sondage, pour
  // une information que le journal détient.
  if (message.action() === Entete.EXECUTION_REPONSE) {
    // Toutes les réponses n'en portent pas : une vérification de système n'a
    // rien à joindre.
    const aUnJustificatif = message.aUnJustificatif()

    return depotJournal.consigneReponseRecue({
      ...commun,
      typeMime: aUnJustificatif ? 'application/pdf' : undefined,
      empreinteJustificatif: aUnJustificatif
        ? adaptateurChiffrement.empreinteSha256(message.pieceJustificative())
        : undefined,
    })
  }

  // Une requête entrante, elle, ouvre la conversation de notre côté : personne
  // d'autre n'y consignera qui demande quoi à qui.
  const requeteur = message.requeteur()
  const identiteFournisseur = fournisseurFrancais.identiteEbms()

  return depotJournal.consigneRequeteRecue({
    ...commun,
    idRequete: message.idRequete(),
    autoriteRequerante: requeteur.id,
    schemaAutoriteRequerante: requeteur.typeId,
    autoriteFournisseuse: identiteFournisseur.id,
    schemaAutoriteFournisseuse: identiteFournisseur.typeId,
    sujetJustificatif: message.beneficiaire().identifiantPourJournal(),
    typeJustificatif: message.typeJustificatif().id,
    codeDemarche: message.codeDemarche(),
  })
}

module.exports = journaliseMessageRecu
