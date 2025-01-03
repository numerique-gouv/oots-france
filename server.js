const EcouteurDomibus = require('./src/ecouteurDomibus');
const OOTS_FRANCE = require('./src/ootsFrance');
const adaptateurChiffrement = require('./src/adaptateurs/adaptateurChiffrement');
const AdaptateurDomibus = require('./src/adaptateurs/adaptateurDomibus');
const adaptateurEnvironnement = require('./src/adaptateurs/adaptateurEnvironnement');
const adaptateurUUID = require('./src/adaptateurs/adaptateurUUID');
const horodateur = require('./src/adaptateurs/horodateur');
const transmetteurPiecesJustificatives = require('./src/adaptateurs/transmetteurPiecesJustificatives');
const DepotPointsAcces = require('./src/depots/depotPointsAcces');
const DepotRequeteurs = require('./src/depots/depotRequeteurs');
const DepotServicesCommuns = require('./src/depots/depotServicesCommunsLocal');
const nouveauMiddleware = require('./src/routes/middleware');

const adaptateurDomibus = AdaptateurDomibus({ adaptateurUUID, horodateur });
const depotPointsAcces = new DepotPointsAcces(adaptateurDomibus);
const depotRequeteurs = new DepotRequeteurs();
const depotServicesCommuns = new DepotServicesCommuns();
const ecouteurDomibus = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 1000 });
const middleware = nouveauMiddleware(adaptateurEnvironnement);

const serveur = OOTS_FRANCE.creeServeur({
  adaptateurChiffrement,
  adaptateurDomibus,
  adaptateurEnvironnement,
  adaptateurUUID,
  depotPointsAcces,
  depotRequeteurs,
  depotServicesCommuns,
  ecouteurDomibus,
  horodateur,
  middleware,
  transmetteurPiecesJustificatives,
});

const port = process.env.PORT || 3000;

serveur.ecoute(port, () => {
  /* eslint-disable no-console */

  console.log(`OOTS-France est démarré et écoute le port ${port} !…`);

  /* eslint-enable no-console */
});

ecouteurDomibus.ecoute();
