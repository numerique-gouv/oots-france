// Test e2e : joue une requête de justificatif à travers un vrai Domibus.
// Contrairement à la suite `test/`, rien n'est simulé ici — le scénario, ses
// prérequis et son dépannage sont décrits dans docs/test_e2e.md.
//
// Cette suite n'est pas jouée par `npm test` (elle exige la pile démarrée) :
// elle a sa propre configuration Jest et se lance par `scripts/testE2e.sh`.

const fs = require('node:fs')
const express = require('express')
const jose = require('jose')

const adaptateurChiffrement = require('../src/adaptateurs/adaptateurChiffrement')
const AdaptateurPostgres = require('../src/adaptateurs/adaptateurPostgres')
const DepotJournal = require('../src/depots/depotJournal')

const ID_REQUETEUR = '00000000000002'
// `00` est le code démarche de vérification système : c'est le seul auquel
// l'application répond par un justificatif (cf. src/domibus/requete.js).
const CODE_DEMARCHE = '00'
const CODE_PAYS = 'FR'
const BENEFICIAIRE = { dateNaissance: '1965-11-25', nomUsage: 'Dupont', prenom: 'Sophie' }
const DELAI_MAX_ATTENTE = 60000

// L'annuaire fait foi : le faux requêteur écoute sur le port que l'application
// ira interroger, quel que soit l'hôte par lequel elle le joint.
const donneesRequeteur = () => {
  const requeteurs = JSON.parse(process.env.DONNEES_REQUETEURS ?? '{}')
  const requeteur = requeteurs[ID_REQUETEUR]

  if (typeof requeteur === 'undefined') {
    throw new Error(`DONNEES_REQUETEURS ne déclare aucun requêteur "${ID_REQUETEUR}".`)
  }

  // Une URL sans port explicite donne `''`, dont `Number` fait 0 : le faux
  // requêteur écouterait alors un port tiré au hasard, que l'application
  // n'irait pas interroger — elle échouerait à déchiffrer le jeton, sans que
  // rien ne désigne l'annuaire.
  const { port } = new URL(requeteur.url)
  if (port === '') {
    throw new Error(`L'URL du requêteur "${ID_REQUETEUR}" doit porter un port explicite, dont le faux requêteur tire son écoute (actuellement : ${requeteur.url}).`)
  }

  return { url: requeteur.url, port: Number(port) }
}

// Vérifie que l'environnement décrit bien le scénario joué, pour échouer sur un
// message clair plutôt que sur un 501 ou un 500 à déchiffrer.
const verifieConfiguration = () => {
  // Symptôme le plus courant : le test lancé depuis la machine hôte, où le
  // contenu de `.env.oots` n'est pas chargé.
  if (typeof process.env.URL_OOTS_FRANCE === 'undefined') {
    throw new Error('Aucune variable d\'environnement chargée : ce test doit tourner dans le conteneur `web`, via `scripts/testE2e.sh`.')
  }

  if (process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE !== 'true') {
    throw new Error('AVEC_REQUETE_PIECE_JUSTIFICATIVE doit valoir `true` : sans quoi l\'API répond 501.')
  }

  const servicesCommuns = JSON.parse(process.env.DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL ?? '{}')
  if (!servicesCommuns.demarches?.some(d => d.code === CODE_DEMARCHE)) {
    throw new Error(`DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL ne déclare aucune démarche "${CODE_DEMARCHE}".`)
  }
}

// La clé publique de chiffrement d'OOTS-France se déduit de sa clé privée en
// lui retirant la composante privée `d`.
const clePubliqueOotsFrance = () => {
  const clePrivee = JSON.parse(atob(process.env.CLE_PRIVEE_JWK_EN_BASE64))
  const clePublique = Object.fromEntries(
    Object.entries(clePrivee).filter(([composante]) => composante !== 'd'),
  )
  return jose.importJWK(clePublique, 'ECDH-ES')
}

// Le faux requêteur joue le fournisseur de service consommateur : il publie les
// clés qui signent les jetons bénéficiaire, encaisse le justificatif que
// l'application lui retransmet et sert d'URL de retour.
const demarreFauxRequeteur = (port, clePublique, idClePublique) => new Promise((resolve) => {
  const recus = {}
  const app = express()

  app.use(express.json({ limit: '50mb' }))

  app.get('/auth/cles_publiques', (_requete, reponse) => {
    reponse.json({
      keys: [{
        ...clePublique, kid: idClePublique, use: 'sig', alg: 'ES256',
      }],
    })
  })

  app.post('/oots/document', (requete, reponse) => {
    recus.document = requete.body.document
    reponse.sendStatus(200)
  })

  // L'application y redirige le navigateur en fin de parcours. Le test ne suit
  // pas la redirection — il en vérifie la cible — mais la route existe pour que
  // le faux requêteur honore le contrat.
  app.get('/oots/callback', (_requete, reponse) => reponse.sendStatus(200))

  const serveur = app.listen(port, () => resolve({ serveur, recus }))
})

// Le bénéficiaire voyage en JWT signé par le requêteur, lui-même chiffré pour
// OOTS-France (cf. src/adaptateurs/adaptateurChiffrement.js).
const construitBeneficiaireChiffre = async (clePrivee, idClePublique) => {
  const jeton = await new jose.SignJWT(BENEFICIAIRE)
    .setProtectedHeader({ alg: 'ES256', kid: idClePublique })
    .setIssuedAt()
    .setExpirationTime('10m')
    .sign(clePrivee)

  return new jose.CompactEncrypt(new TextEncoder().encode(jeton))
    .setProtectedHeader({ alg: 'ECDH-ES', enc: 'A256GCM' })
    .encrypt(await clePubliqueOotsFrance())
}

const attend = condition => new Promise((resolve, reject) => {
  const debut = Date.now()
  const idIntervalle = setInterval(() => {
    if (condition()) {
      clearInterval(idIntervalle)
      resolve()
    }
    else if (Date.now() - debut > DELAI_MAX_ATTENTE) {
      clearInterval(idIntervalle)
      reject(new Error(`aucun justificatif reçu après ${DELAI_MAX_ATTENTE / 1000} s`))
    }
  }, 200)
})

// Le justificatif arrive sérialisé en JSON : un Buffer y devient
// `{ type: 'Buffer', data: [...] }`.
const enBuffer = (document) => {
  if (typeof document === 'string') return Buffer.from(document, 'base64')
  if (document?.type === 'Buffer') return Buffer.from(document.data)
  // Rendre un tampon vide ferait échouer la comparaison sur une longueur nulle,
  // en laissant croire à un justificatif perdu plutôt qu'à une forme imprévue.
  throw new Error(`Justificatif reçu sous une forme imprévue : ${JSON.stringify(document).slice(0, 200)}`)
}

describe('Une requête de pièce justificative', () => {
  let fauxRequeteur
  let urlRequeteur
  let beneficiaireChiffre
  let adaptateurPostgres
  let depotJournal

  beforeAll(async () => {
    verifieConfiguration()
    const { url, port } = donneesRequeteur()
    urlRequeteur = url

    const { privateKey, publicKey } = await jose.generateKeyPair('ES256', { extractable: true })
    const clePublique = await jose.exportJWK(publicKey)
    const idClePublique = await jose.calculateJwkThumbprint(clePublique)

    fauxRequeteur = await demarreFauxRequeteur(port, clePublique, idClePublique)
    beneficiaireChiffre = await construitBeneficiaireChiffre(privateKey, idClePublique)

    adaptateurPostgres = AdaptateurPostgres({ urlBaseDonnees: process.env.URL_BASE_DONNEES })
    depotJournal = new DepotJournal(adaptateurPostgres)
  })

  afterAll(async () => {
    if (typeof adaptateurPostgres !== 'undefined') await adaptateurPostgres.fermeConnexions()

    // `beforeAll` peut échouer avant d'avoir monté le faux requêteur : sans
    // cette garde, l'erreur de fermeture masquerait la vraie cause de l'échec.
    await new Promise((resolve) => {
      if (typeof fauxRequeteur === 'undefined') resolve()
      else fauxRequeteur.serveur.close(resolve)
    })
  })

  it('revient du fournisseur avec le justificatif attendu, à travers Domibus', async () => {
    const parametres = new URLSearchParams({
      codeDemarche: CODE_DEMARCHE,
      codePays: CODE_PAYS,
      idRequeteur: ID_REQUETEUR,
      beneficiaire: beneficiaireChiffre,
    })

    const reponse = await fetch(
      `${process.env.URL_OOTS_FRANCE}/requete/pieceJustificative?${parametres}`,
      { redirect: 'manual' },
    )

    // Le corps n'est lu qu'en cas d'échec, pour que le diff Jest porte le
    // message d'erreur de l'application plutôt qu'un simple code.
    const statut = reponse.status === 302 ? '302' : `${reponse.status} : ${await reponse.text()}`
    expect(statut).toBe('302')

    expect(reponse.headers.get('location')).toBe(`${urlRequeteur}/oots/callback`)

    await attend(() => typeof fauxRequeteur.recus.document !== 'undefined')

    const justificatif = enBuffer(fauxRequeteur.recus.document)
    const attendu = fs.readFileSync('./assets/drapeau.pdf')

    expect(justificatif.subarray(0, 4).toString()).toBe('%PDF')
    expect(justificatif.length).toBe(attendu.length)
    expect(justificatif.equals(attendu)).toBe(true)
  })

  // Enchaîné sur l'échange ci-dessus plutôt que joué dans sa propre suite :
  // c'est le même scénario qu'il inspecte, et le rejouer coûterait un second
  // aller-retour à travers Domibus pour la même chose. C'est ici que le SQL du
  // journal est réellement exercé — la suite unitaire ne touche pas la base.
  describe('une fois l\'échange abouti', () => {
    // La passerelle dialogue avec elle-même : les cinq événements d'un échange
    // abouti, ceux du requêteur comme ceux du fournisseur, tombent dans le
    // même journal.
    const TYPES_ATTENDUS = [
      'requete_emise',
      'requete_recue',
      'reponse_emise',
      'reponse_recue',
      'piece_transmise',
    ]

    let evenements

    beforeAll(async () => {
      const [derniere] = await depotJournal.dernieresConversations({ limite: 1 })
      expect(derniere).toBeDefined()

      evenements = await depotJournal.evenementsDeConversation(derniere.id_conversation)
    })

    it('journalise chaque étape de la conversation', () => {
      const types = evenements.map(e => e.type_evenement)

      TYPES_ATTENDUS.forEach(type => expect(types).toContain(type))
    })

    it('consigne l\'empreinte du justificatif, et jamais le justificatif', () => {
      const attendue = adaptateurChiffrement.empreinteSha256(fs.readFileSync('./assets/drapeau.pdf'))
      const avecEmpreinte = evenements.filter(e => e.empreinte_justificatif !== null)

      expect(avecEmpreinte.length).toBeGreaterThan(0)
      avecEmpreinte.forEach(e => expect(e.empreinte_justificatif).toBe(attendue))

      // Le justificatif est un PDF : nulle colonne ne doit en porter l'en-tête.
      evenements.forEach(e => Object.values(e).forEach((valeur) => {
        if (typeof valeur === 'string') expect(valeur).not.toContain('%PDF')
      }))
    })

    it('chaîne les empreintes sans rupture', async () => {
      expect(await depotJournal.verifieChaine()).toEqual([])
    })

    it('refuse que le rôle applicatif modifie ou supprime une ligne', async () => {
      const [{ id }] = evenements

      await expect(adaptateurPostgres.requete('UPDATE journal_echanges SET code_demarche = $1 WHERE id = $2', ['XX', id]))
        .rejects.toThrow(/permission denied/)
      await expect(adaptateurPostgres.requete('DELETE FROM journal_echanges WHERE id = $1', [id]))
        .rejects.toThrow(/permission denied/)
    })
  })
})
