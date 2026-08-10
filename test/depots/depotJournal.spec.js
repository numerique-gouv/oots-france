const DepotJournal = require('../../src/depots/depotJournal')

// La base n'est pas jouée ici : la suite unitaire tourne sur un runner nu.
// Ce que ces tests garantissent, c'est que le dépôt place la bonne valeur dans
// le bon paramètre — le SQL lui-même est exercé par `test-e2e/`.
const adaptateurFactice = (reponse = []) => {
  const appels = []

  return {
    appels,
    requete: (texte, valeurs = []) => {
      appels.push({ texte, valeurs })
      return Promise.resolve(reponse)
    },
  }
}

// Les colonnes de l'ordre d'insertion, dans l'ordre des paramètres.
const COLONNES_INSERTION = [
  'type_evenement',
  'action_ebms',
  'id_conversation',
  'id_message',
  'id_echange',
  'id_requete',
  'id_reponse',
  'autorite_requerante',
  'schema_autorite_requerante',
  'autorite_fournisseuse',
  'schema_autorite_fournisseuse',
  'id_requeteur',
  'sujet_justificatif',
  'type_justificatif',
  'code_demarche',
  'type_mime',
  'empreinte_justificatif',
  'code_erreur',
]

const valeurInseree = (appel, colonne) => appel.valeurs[COLONNES_INSERTION.indexOf(colonne)]

describe('Le dépôt du journal', () => {
  it('consigne une requête émise avec son contexte métier', () => {
    const adaptateur = adaptateurFactice()
    const depot = new DepotJournal(adaptateur)

    return depot.consigneRequeteEmise({
      actionEbms: 'ExecuteQueryRequest',
      idConversation: 'conv-1',
      idMessage: 'msg-1@oots.eu',
      idRequete: 'urn:uuid:requete-1',
      autoriteRequerante: '12345678901234',
      schemaAutoriteRequerante: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots',
      idRequeteur: '98765432109876',
      sujetJustificatif: 'FR/DE/1234',
      typeJustificatif: 'EDUCATION_DIPLOMA',
      codeDemarche: 'T1',
    })
      .then(() => {
        expect(adaptateur.appels).toHaveLength(1)
        const [appel] = adaptateur.appels

        expect(appel.texte).toContain('INSERT INTO journal_echanges')
        expect(valeurInseree(appel, 'type_evenement')).toBe('requete_emise')
        expect(valeurInseree(appel, 'id_conversation')).toBe('conv-1')
        // Voisines et positionnelles : une inversion des deux passerait sans
        // cela inaperçue.
        expect(valeurInseree(appel, 'id_requete')).toBe('urn:uuid:requete-1')
        expect(valeurInseree(appel, 'id_reponse')).toBeUndefined()
        expect(valeurInseree(appel, 'code_demarche')).toBe('T1')
        expect(valeurInseree(appel, 'sujet_justificatif')).toBe('FR/DE/1234')
        expect(valeurInseree(appel, 'id_requeteur')).toBe('98765432109876')
      })
  })

  it('laisse vides les colonnes que l\'événement ne renseigne pas', () => {
    const adaptateur = adaptateurFactice()
    const depot = new DepotJournal(adaptateur)

    return depot.consigneRequeteRefusee({ idConversation: 'conv-2', codeErreur: 'ErreurCodeDemarcheIntrouvable' })
      .then(() => {
        const [appel] = adaptateur.appels

        expect(appel.valeurs).toHaveLength(COLONNES_INSERTION.length)
        expect(valeurInseree(appel, 'type_evenement')).toBe('requete_refusee')
        expect(valeurInseree(appel, 'code_erreur')).toBe('ErreurCodeDemarcheIntrouvable')
        expect(valeurInseree(appel, 'id_message')).toBeUndefined()
        expect(valeurInseree(appel, 'empreinte_justificatif')).toBeUndefined()
      })
  })

  it('ne consigne jamais le justificatif lui-même, mais son empreinte', () => {
    const adaptateur = adaptateurFactice()
    const depot = new DepotJournal(adaptateur)

    return depot.consigneReponseRecue({
      idConversation: 'conv-1',
      typeMime: 'application/pdf',
      empreinteJustificatif: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    })
      .then(() => {
        const [appel] = adaptateur.appels

        expect(valeurInseree(appel, 'empreinte_justificatif'))
          .toBe('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855')
      })
  })

  it('nomme chaque type d\'événement selon le vocabulaire du chapitre 4.8', () => {
    const adaptateur = adaptateurFactice()
    const depot = new DepotJournal(adaptateur)

    return Promise.all([
      depot.consigneReponseRecue({}),
      depot.consigneErreurRecue({}),
      depot.consigneRequeteRecue({}),
      depot.consigneReponseEmise({}),
      depot.consignePieceTransmise({}),
    ])
      .then(() => {
        const types = adaptateur.appels.map(appel => valeurInseree(appel, 'type_evenement'))

        expect(types).toEqual([
          'reponse_recue',
          'erreur_recue',
          'requete_recue',
          'reponse_emise',
          'piece_transmise',
        ])
      })
  })

  it('cherche une conversation sur un préfixe de son identifiant', () => {
    const adaptateur = adaptateurFactice()
    const depot = new DepotJournal(adaptateur)

    return depot.evenementsDeConversation('52f1c57d')
      .then(() => {
        const [appel] = adaptateur.appels

        expect(appel.texte).toContain('starts_with(id_conversation, $1)')
        expect(appel.valeurs).toEqual(['52f1c57d'])
      })
  })

  it('liste les dernières conversations, les plus récentes en tête', () => {
    const adaptateur = adaptateurFactice()
    const depot = new DepotJournal(adaptateur)

    return depot.dernieresConversations()
      .then(() => {
        const [appel] = adaptateur.appels

        expect(appel.texte).toContain('vue_dernieres_conversations')
        expect(appel.texte).toContain('ORDER BY debut DESC')
        expect(appel.valeurs).toEqual([undefined, undefined, false, 20])
      })
  })

  it('passe ses filtres à la base plutôt que de trier en mémoire', () => {
    const adaptateur = adaptateurFactice()
    const depot = new DepotJournal(adaptateur)

    return depot.dernieresConversations({
      limite: 5,
      depuis: '2026-08-01T00:00:00Z',
      requeteur: '12345678901234',
      erreursSeulement: true,
    })
      .then(() => {
        const [appel] = adaptateur.appels

        expect(appel.valeurs).toEqual(['2026-08-01T00:00:00Z', '12345678901234', true, 5])
      })
  })

  it('ne rend que les maillons rompus quand il vérifie la chaîne', () => {
    const adaptateur = adaptateurFactice([{ id: 3, empreinte_valide: false, maillon_valide: true }])
    const depot = new DepotJournal(adaptateur)

    return depot.verifieChaine()
      .then((ruptures) => {
        const [appel] = adaptateur.appels

        expect(appel.texte).toContain('WHERE NOT empreinte_valide OR NOT maillon_valide')
        expect(ruptures).toHaveLength(1)
        expect(ruptures[0].id).toBe(3)
      })
  })
})
