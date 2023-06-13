const OOTS_FRANCE = require('./src/ootsFrance');
const adaptateurUUID = require('./src/adaptateurs/adaptateurUUID');

const port = process.env.PORT || 3000;
const serveur = OOTS_FRANCE.creeServeur({ adaptateurUUID });
serveur.ecoute(port, () => {
  /* eslint-disable no-console */

  console.log(`OOTS-France est démarré et écoute le port ${port} !…`);

  /* eslint-enable no-console */
});
