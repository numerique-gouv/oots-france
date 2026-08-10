// Consulte le journal des échanges (chapitre 4.8 des TDD).
//
//   npm run journal                          les dernières conversations
//   npm run journal -- --erreurs --limite 5  filtrées
//   npm run journal 52f1c57d                 le détail d'une conversation
//   npm run journal 52f1c57d -- --json       les lignes brutes
//
// Le mode détail n'abrège rien : un identifiant tronqué ne se recopie pas dans
// la console Domibus, une empreinte tronquée ne se revérifie pas. L'abréviation
// est réservée à la liste, où elle sert à balayer.

const { parseArgs } = require('node:util')

const AdaptateurPostgres = require('../src/adaptateurs/adaptateurPostgres')
const DepotJournal = require('../src/depots/depotJournal')

// Dans l'ordre d'affichage. Les deux schémas d'identifiant n'y figurent pas :
// ils s'écrivent sous l'autorité qu'ils qualifient.
const LIBELLES = {
  action_ebms: 'action ebMS',
  id_message: 'id message',
  id_echange: 'id échange',
  id_requete: 'id requête',
  id_reponse: 'id réponse',
  autorite_requerante: 'autorité requérante',
  autorite_fournisseuse: 'autorité fournisseuse',
  id_requeteur: 'requêteur',
  sujet_justificatif: 'sujet',
  type_justificatif: 'type de justificatif',
  code_demarche: 'démarche',
  type_mime: 'type MIME',
  empreinte_justificatif: 'empreinte justificatif',
  code_erreur: 'code erreur',
  empreinte: 'empreinte',
  empreinte_precedente: 'empreinte précédente',
}

const SCHEMAS = {
  autorite_requerante: 'schema_autorite_requerante',
  autorite_fournisseuse: 'schema_autorite_fournisseuse',
}

const LARGEUR_LIBELLE = Math.max(...Object.values(LIBELLES).map(l => l.length)) + 2

const renseigne = valeur => valeur !== null && typeof valeur !== 'undefined' && valeur !== ''

const ligne = (libelle, valeur) => `   ${libelle.padEnd(LARGEUR_LIBELLE)}${valeur}`

const premiereValeur = (evenements, colonne) => evenements.map(e => e[colonne]).find(renseigne)

const afficheEvenement = (evenement) => {
  console.log(`\n── ${evenement.horodatage.toISOString()}   ${evenement.type_evenement} ${'─'.repeat(30)}`)

  Object.entries(LIBELLES).forEach(([colonne, libelle]) => {
    if (!renseigne(evenement[colonne])) return

    console.log(ligne(libelle, evenement[colonne]))

    const schema = evenement[SCHEMAS[colonne]]
    if (renseigne(schema)) console.log(ligne('', schema))
  })

  // Seule la toute première ligne du journal en est dépourvue — ou la plus
  // ancienne survivante d'une purge, dont le maillon a disparu avec elle.
  if (!renseigne(evenement.empreinte_precedente)) {
    console.log(ligne('empreinte précédente', '(aucune — début de chaîne)'))
  }
}

const afficheConversation = (evenements) => {
  const entete = [
    ['Conversation', premiereValeur(evenements, 'id_conversation')],
    ['Échange', premiereValeur(evenements, 'id_echange')],
    ['Requêteur', premiereValeur(evenements, 'id_requeteur')],
    ['Démarche', premiereValeur(evenements, 'code_demarche')],
    ['Justificatif', premiereValeur(evenements, 'type_justificatif')],
    ['Sujet', premiereValeur(evenements, 'sujet_justificatif')],
  ].filter(([, valeur]) => renseigne(valeur))

  console.log('')
  entete.forEach(([libelle, valeur]) => console.log(`${libelle.padEnd(15)}${valeur}`))

  evenements.forEach(afficheEvenement)

  const alterees = evenements.filter(e => !e.empreinte_valide)
  const debut = evenements[0].horodatage.toISOString()
  const fin = evenements[evenements.length - 1].horodatage.toISOString()

  console.log('')
  if (alterees.length === 0) {
    console.log(`Chaîne d'empreintes : valide — ${evenements.length} événement(s), de ${debut} à ${fin}`)
  }
  else {
    // Le journal n'a pas seulement perdu une ligne : quelqu'un l'a réécrite
    // après coup, en base et sous un rôle qui en avait le droit.
    console.log(`⚠️  Chaîne d'empreintes : ROMPUE sur ${alterees.length} événement(s) — ${alterees.map(e => e.id).join(', ')}`)
  }
}

const afficheListe = (conversations) => {
  if (conversations.length === 0) {
    console.log('\nAucune conversation journalisée.')
    return
  }

  const etat = c => (renseigne(c.dernier_code_erreur)
    ? `${c.dernier_evenement} (${c.dernier_code_erreur})`
    : c.dernier_evenement)

  const lignes = conversations.map(c => [
    c.debut.toISOString().slice(0, 16).replace('T', ' '),
    c.id_conversation.slice(0, 8),
    c.code_demarche ?? '',
    c.id_requeteur ?? '',
    etat(c),
    String(c.nombre_evenements),
  ])

  const entetes = ['début', 'conversation', 'démarche', 'requêteur', 'état', 'évén.']
  const largeurs = entetes.map((e, i) => Math.max(e.length, ...lignes.map(l => l[i].length)) + 2)
  const formate = cellules => cellules.map((c, i) => c.padEnd(largeurs[i])).join('')

  console.log('')
  console.log(`  ${formate(entetes)}`)
  lignes.forEach(l => console.log(`  ${formate(l)}`))
  console.log(`\n  ${conversations.length} conversation(s) — --limite, --depuis, --requeteur, --erreurs pour filtrer`)
}

const { values: options, positionals } = parseArgs({
  args: process.argv.slice(2),
  options: {
    limite: { type: 'string' },
    depuis: { type: 'string' },
    requeteur: { type: 'string' },
    erreurs: { type: 'boolean' },
    json: { type: 'boolean' },
  },
  allowPositionals: true,
})

const adaptateurPostgres = AdaptateurPostgres({ urlBaseDonnees: process.env.URL_BASE_DONNEES })
const depotJournal = new DepotJournal(adaptateurPostgres)
const [prefixeIdConversation] = positionals

const detaille = () => depotJournal.evenementsDeConversation(prefixeIdConversation)
  .then((evenements) => {
    if (options.json) return console.log(JSON.stringify(evenements, null, 2))

    if (evenements.length === 0) {
      return console.log(`\nAucune conversation dont l'identifiant commence par « ${prefixeIdConversation} ».`)
    }

    const conversations = [...new Set(evenements.map(e => e.id_conversation))]
    if (conversations.length > 1) {
      console.log(`\n${conversations.length} conversations commencent par « ${prefixeIdConversation} » — préciser :`)
      return conversations.forEach(c => console.log(`  ${c}`))
    }

    return afficheConversation(evenements)
  })

const liste = () => depotJournal.dernieresConversations({
  limite: options.limite ? Number(options.limite) : undefined,
  depuis: options.depuis,
  requeteur: options.requeteur,
  erreursSeulement: options.erreurs,
})
  .then(conversations => (options.json
    ? console.log(JSON.stringify(conversations, null, 2))
    : afficheListe(conversations)))

const consultation = prefixeIdConversation ? detaille() : liste()

consultation
  .catch((e) => {
    console.error(e.message)
    process.exitCode = 1
  })
  .finally(() => adaptateurPostgres.fermeConnexions())
