const OOTS_FRANCE = require('./src/ootsFrance');
const AdaptateurDomibus = require('./src/adaptateurs/adaptateurDomibus');
const adaptateurUUID = require('./src/adaptateurs/adaptateurUUID');
const horodateur = require('./src/adaptateurs/horodateur');

const adaptateurDomibus = AdaptateurDomibus({ adaptateurUUID, horodateur });

const serveur = OOTS_FRANCE.creeServeur({
  adaptateurDomibus,
  adaptateurUUID,
  horodateur,
});

const port = process.env.PORT || 3000;

serveur.ecoute(port, () => {
  /* eslint-disable no-console */

  console.log(`OOTS-France est démarré et écoute le port ${port} !…`);

  /* eslint-enable no-console */
});

adaptateurDomibus.ecoute();
