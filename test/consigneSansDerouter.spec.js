const consigneSansDerouter = require('../src/consigneSansDerouter')

describe('L\'écriture au journal qui ne déroute pas', () => {
  let erreursJournalisees
  let consoleInitiale

  beforeEach(() => {
    erreursJournalisees = []
    consoleInitiale = console.error
    console.error = (...args) => erreursJournalisees.push(args)
  })

  afterEach(() => {
    console.error = consoleInitiale
  })

  it('rend la valeur écrite quand tout se passe bien', () => (
    consigneSansDerouter(() => Promise.resolve('écrit'), 'Requête émise', () => 'conversation 1')
      .then((valeur) => {
        expect(valeur).toBe('écrit')
        expect(erreursJournalisees).toHaveLength(0)
      })
  ))

  it('rattrape le refus de la base sans le relancer', () => (
    consigneSansDerouter(
      () => Promise.reject(new Error('base indisponible')),
      'Requête émise',
      () => 'conversation 1',
    )
      .then(() => {
        const [message, echec] = erreursJournalisees[0]

        expect(message).toBe('Requête émise sans trace au journal (conversation 1) :')
        expect(echec.message).toBe('base indisponible')
      })
  ))

  // La raison d'être du thunk : une erreur levée en assemblant l'événement —
  // un slot RegRep absent d'un message inattendu — n'aurait aucune promesse à
  // laquelle s'accrocher si l'écriture était déjà lancée à l'appel.
  it('rattrape aussi l\'erreur levée en assemblant l\'événement', () => (
    consigneSansDerouter(
      () => { throw new Error('slot RegRep absent') },
      'Message traité',
      () => 'conversation 1',
    )
      .then(() => {
        const [message, echec] = erreursJournalisees[0]

        expect(message).toBe('Message traité sans trace au journal (conversation 1) :')
        expect(echec.message).toBe('slot RegRep absent')
      })
  ))

  // Le détail relit les mêmes identifiants que l'écriture : il peut échouer
  // pour les mêmes causes. La trace vaut mieux approximative que perdue.
  it('journalise quand même si le détail lui-même est illisible', () => (
    consigneSansDerouter(
      () => Promise.reject(new Error('base indisponible')),
      'Message traité',
      () => { throw new Error('entête illisible') },
    )
      .then(() => {
        const [message, echec] = erreursJournalisees[0]

        expect(message).toBe('Message traité sans trace au journal (contexte illisible) :')
        expect(echec.message).toBe('base indisponible')
      })
  ))

  // L'erreur entière, et non son seul message : sans la pile, un incident
  // resté six mois au journal ne se rattache à rien.
  it('journalise l\'erreur entière, pas seulement son message', () => {
    const echec = new Error('base indisponible')
    echec.code = '57014'

    return consigneSansDerouter(() => Promise.reject(echec), 'Requête refusée', () => 'conversation 1')
      .then(() => expect(erreursJournalisees[0][1]).toBe(echec))
  })
})
