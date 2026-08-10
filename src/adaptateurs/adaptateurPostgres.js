const { Pool } = require('pg')

const AdaptateurPostgres = (config = {}) => {
  const pool = new Pool({ connectionString: config.urlBaseDonnees })

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
