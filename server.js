const EcouteurDomibus = require('./src/ecouteurDomibus');
const OOTS_FRANCE = require('./src/ootsFrance');
const AdaptateurDomibus = require('./src/adaptateurs/adaptateurDomibus');
const adaptateurEnvironnement = require('./src/adaptateurs/adaptateurEnvironnement');
const adaptateurUUID = require('./src/adaptateurs/adaptateurUUID');
const horodateur = require('./src/adaptateurs/horodateur');
const DepotPointsAcces = require('./src/depots/depotPointsAcces');

const adaptateurDomibus = AdaptateurDomibus({ adaptateurUUID, horodateur });
const depotPointsAcces = new DepotPointsAcces(adaptateurDomibus);
const ecouteurDomibus = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 1000 });

const serveur = OOTS_FRANCE.creeServeur({
  adaptateurDomibus,
  adaptateurEnvironnement,
  adaptateurUUID,
  depotPointsAcces,
  ecouteurDomibus,
  horodateur,
});

const port = process.env.PORT || 3000;

serveur.ecoute(port, () => {
  /* eslint-disable no-console */

  console.log(`OOTS-France est démarré et écoute le port ${port} !…`);

  /* eslint-enable no-console */
});

ecouteurDomibus.ecoute();
