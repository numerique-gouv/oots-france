const OOTS_FRANCE = require('./src/ootsFrance');

const port = process.env.PORT || 3000;
const serveur = OOTS_FRANCE.creeServeur();
serveur.ecoute(port, () => {
  console.log(`OOTS-France est démarré et écoute le port ${port} !…`);
});

