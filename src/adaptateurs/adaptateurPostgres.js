const { Pool } = require('pg')

// Une base qui ralentit sans tomber ne produit ni erreur ni rejet : la
// promesse ne se résout jamais. Le rattrapage des écritures protège de
// l'échec, pas du silence — et ce silence bloquerait la réponse au requêteur,
// pendant que le cycle de sondage, lui, continue de consommer des messages
// chez la passerelle. Ces délais transforment le blocage en refus, que le
// rattrapage sait traiter.
//
// Cinq secondes : trois ordres de grandeur au-dessus d'une insertion dans ce
// journal, et bien en deçà du délai d'attente d'une réponse Domibus.
const DELAI_MAX_REQUETE = 5000

const AdaptateurPostgres = (config = {}) => {
  const pool = new Pool({
    connectionString: config.urlBaseDonnees,
    // Côté serveur, pour que la requête soit réellement abandonnée ; côté
    // client, pour le cas où la connexion elle-même ne répond plus.
    statement_timeout: DELAI_MAX_REQUETE,
    query_timeout: DELAI_MAX_REQUETE,
    connectionTimeoutMillis: DELAI_MAX_REQUETE,
  })

  // `pg` émet cet événement quand une connexion inactive tombe — la base
  // redémarre, un pare-feu coupe. Sans écouteur, l'événement `error` d'un
  // EventEmitter est relancé en exception et emporte le processus, alors que le
  // pool sait remplacer la connexion tout seul.
  pool.on('error', e => console.error(e))

  const requete = (texte, valeurs = []) => pool.query(texte, valeurs).then(({ rows }) => rows)

  const fermeConnexions = () => pool.end()

  return {
    fermeConnexions,
    requete,
  }
}

module.exports = AdaptateurPostgres
