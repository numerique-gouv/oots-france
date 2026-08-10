const EcouteurDomibus = require('./src/ecouteurDomibus')
const OOTS_FRANCE = require('./src/ootsFrance')
const adaptateurChiffrement = require('./src/adaptateurs/adaptateurChiffrement')
const AdaptateurDomibus = require('./src/adaptateurs/adaptateurDomibus')
const adaptateurEnvironnement = require('./src/adaptateurs/adaptateurEnvironnement')
const AdaptateurPostgres = require('./src/adaptateurs/adaptateurPostgres')
const adaptateurUUID = require('./src/adaptateurs/adaptateurUUID')
const horodateur = require('./src/adaptateurs/horodateur')
const Fournisseur = require('./src/ebms/fournisseur')
const transmetteurPiecesJustificatives = require('./src/adaptateurs/transmetteurPiecesJustificatives')
const DepotJournal = require('./src/depots/depotJournal')
const DepotPointsAcces = require('./src/depots/depotPointsAcces')
const DepotRequeteurs = require('./src/depots/depotRequeteurs')
const DepotServicesCommuns = require('./src/depots/depotServicesCommunsLocal')
const nouveauMiddleware = require('./src/routes/middleware')

// Lue au démarrage : une identité absente ou vide partirait sinon en
// `undefined` dans chaque réponse et chaque erreur émises, sans que rien ne
// s'en plaigne. L'accesseur lève une `ErreurConfiguration`, qui arrête ici.
const fournisseurFrancais = Fournisseur.francais(adaptateurEnvironnement.identiteFournisseurFrancais())

const adaptateurPostgres = AdaptateurPostgres({
  urlBaseDonnees: adaptateurEnvironnement.urlBaseDonnees(),
})
const depotJournal = new DepotJournal(adaptateurPostgres)
const adaptateurDomibus = AdaptateurDomibus({
  adaptateurChiffrement,
  adaptateurUUID,
  depotJournal,
  fournisseurFrancais,
  horodateur,
})
const depotPointsAcces = new DepotPointsAcces(adaptateurDomibus)
const depotRequeteurs = new DepotRequeteurs()
const depotServicesCommuns = new DepotServicesCommuns()
const ecouteurDomibus = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 1000 })
const middleware = nouveauMiddleware(adaptateurEnvironnement)

const serveur = OOTS_FRANCE.creeServeur({
  adaptateurChiffrement,
  adaptateurDomibus,
  adaptateurEnvironnement,
  adaptateurUUID,
  depotJournal,
  depotPointsAcces,
  depotRequeteurs,
  depotServicesCommuns,
  ecouteurDomibus,
  horodateur,
  middleware,
  transmetteurPiecesJustificatives,
})

const port = process.env.PORT || 3000

serveur.ecoute(port, () => {
  console.log(`OOTS-France est démarré et écoute le port ${port} !…`)
})

ecouteurDomibus.ecoute()
