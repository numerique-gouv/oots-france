// Le journal des échanges de justificatifs exigé par l'article 17 du règlement
// d'exécution (UE) 2022/1463 et le chapitre 4.8 des TDD.
//
// Il consigne ce que la passerelle ignore — contenu RegRep, refus qui n'ont
// jamais produit de message ebMS, requêteur applicatif, devenir de la pièce —
// et redit ce qu'elle connaît déjà, de sorte qu'il se lise seul le jour où elle
// change de main. Il ne porte jamais le justificatif, seulement son empreinte.

// Les colonnes sont nommées une fois pour toutes : `pg` traduit en NULL les
// valeurs absentes, ce qui évite de composer l'ordre SQL selon les champs
// fournis et laisse la requête lisible et grep-able.
const INSERTION = `
  INSERT INTO journal_echanges (
    type_evenement,
    action_ebms,
    id_conversation,
    id_message,
    id_echange,
    id_requete,
    id_reponse,
    autorite_requerante,
    schema_autorite_requerante,
    autorite_fournisseuse,
    schema_autorite_fournisseuse,
    id_requeteur,
    sujet_justificatif,
    type_justificatif,
    code_demarche,
    type_mime,
    empreinte_justificatif,
    code_erreur
  ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
`

class DepotJournal {
  constructor(adaptateurPostgres) {
    this.adaptateurPostgres = adaptateurPostgres
  }

  consigne(typeEvenement, donnees = {}) {
    return this.adaptateurPostgres.requete(INSERTION, [
      typeEvenement,
      donnees.actionEbms,
      donnees.idConversation,
      donnees.idMessage,
      donnees.idEchange,
      donnees.idRequete,
      donnees.idReponse,
      donnees.autoriteRequerante,
      donnees.schemaAutoriteRequerante,
      donnees.autoriteFournisseuse,
      donnees.schemaAutoriteFournisseuse,
      donnees.idRequeteur,
      donnees.sujetJustificatif,
      donnees.typeJustificatif,
      donnees.codeDemarche,
      donnees.typeMime,
      donnees.empreinteJustificatif,
      donnees.codeErreur,
    ])
  }

  consigneRequeteEmise(donnees) {
    return this.consigne('requete_emise', donnees)
  }

  consigneReponseRecue(donnees) {
    return this.consigne('reponse_recue', donnees)
  }

  consigneErreurRecue(donnees) {
    return this.consigne('erreur_recue', donnees)
  }

  consigneRequeteRecue(donnees) {
    return this.consigne('requete_recue', donnees)
  }

  consigneReponseEmise(donnees) {
    return this.consigne('reponse_emise', donnees)
  }

  consignePieceTransmise(donnees) {
    return this.consigne('piece_transmise', donnees)
  }

  // Le refus n'atteint jamais la passerelle : sans cette trace, l'erreur que
  // l'article 17 demande de journaliser n'existerait nulle part.
  consigneRequeteRefusee(donnees) {
    return this.consigne('requete_refusee', donnees)
  }

  dernieresConversations({
    limite = 20,
    depuis,
    requeteur,
    erreursSeulement = false,
  } = {}) {
    return this.adaptateurPostgres.requete(`
      SELECT *
      FROM vue_dernieres_conversations
      WHERE ($1::timestamptz IS NULL OR debut >= $1)
        AND ($2::text IS NULL OR id_requeteur = $2)
        AND (NOT $3 OR dernier_code_erreur IS NOT NULL)
      ORDER BY debut DESC
      LIMIT $4
    `, [depuis, requeteur, erreursSeulement, limite])
  }

  // Un préfixe suffit : les identifiants de conversation sont des UUID, que
  // personne ne recopie en entier depuis la liste. `starts_with` plutôt que
  // `LIKE`, dont les caractères spéciaux seraient interprétés.
  evenementsDeConversation(prefixeIdConversation) {
    return this.adaptateurPostgres.requete(`
      SELECT *, empreinte = empreinte_attendue AS empreinte_valide
      FROM vue_journal_conversation
      WHERE starts_with(id_conversation, $1)
      ORDER BY id
    `, [prefixeIdConversation])
  }

  // Deux ruptures possibles, et deux vérifications : l'empreinte d'une ligne ne
  // correspond plus à son contenu — elle a été modifiée —, ou son maillon ne
  // rattrape plus la ligne précédente — une ligne a disparu entre les deux.
  //
  // La toute première ligne est exemptée de la seconde : après une purge, elle
  // pointe légitimement vers un maillon supprimé.
  verifieChaine() {
    return this.adaptateurPostgres.requete(`
      SELECT id, horodatage, type_evenement, id_conversation, empreinte_valide, maillon_valide
      FROM (
        SELECT
          e.id,
          e.horodatage,
          e.type_evenement,
          e.id_conversation,
          e.empreinte = e.empreinte_attendue AS empreinte_valide,
          lag(e.empreinte) OVER (ORDER BY e.id) IS NULL
            OR e.empreinte_precedente = lag(e.empreinte) OVER (ORDER BY e.id) AS maillon_valide
        FROM vue_journal_conversation e
      ) AS verification
      WHERE NOT empreinte_valide OR NOT maillon_valide
      ORDER BY id
    `)
  }
}

module.exports = DepotJournal
