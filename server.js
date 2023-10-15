const OOTS_FRANCE = require('./src/ootsFrance');
const AdaptateurDomibus = require('./src/adaptateurs/adaptateurDomibus');
const adaptateurUUID = require('./src/adaptateurs/adaptateurUUID');
const horodateur = require('./src/adaptateurs/horodateur');
const EcouteurDomibus = require('./src/ecouteurDomibus');

const adaptateurDomibus = AdaptateurDomibus({ adaptateurUUID, horodateur });
const ecouteurDomibus = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 300 });

const serveur = OOTS_FRANCE.creeServeur({
  adaptateurDomibus,
  adaptateurUUID,
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
