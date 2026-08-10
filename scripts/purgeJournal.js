// Applique la conservation de douze mois de l'article 17 du règlement
// d'exécution (UE) 2022/1463 : supprime du journal les événements plus anciens.
//
// À brancher sur une tâche planifiée de l'hébergement. La suppression appartient
// au propriétaire de la base et non au rôle applicatif, qui n'a que l'ajout et
// la lecture — d'où la connexion de migration.
//
//   npm run purgeJournal

const AdaptateurPostgres = require('../src/adaptateurs/adaptateurPostgres')

const adaptateur = AdaptateurPostgres({
  urlBaseDonnees: process.env.URL_BASE_DONNEES_MIGRATION,
})

adaptateur.requete('SELECT purge_journal_echanges() AS supprimees')
  .then(([{ supprimees }]) => console.log(`${supprimees} événement(s) supprimé(s) du journal.`))
  .catch((e) => {
    console.error(e)
    process.exitCode = 1
  })
  .finally(() => adaptateur.fermeConnexions())
