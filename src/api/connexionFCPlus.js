const SessionFCPlus = require('../modeles/sessionFCPlus');

const connexionFCPlus = (config, code, requete, reponse) => {
  const { adaptateurChiffrement, adaptateurFranceConnectPlus } = config;

  requete.session.jeton = undefined;

  const sessionFCPlus = new SessionFCPlus(
    { adaptateurChiffrement, adaptateurFranceConnectPlus },
    code,
  );

  return sessionFCPlus.enJSON()
    .then((infos) => adaptateurChiffrement.genereJeton(infos)
      .then((jwt) => { requete.session.jeton = jwt; })
      .then(() => reponse.json(infos)))
    .catch((e) => reponse.status(502).json({ erreur: `Échec authentification (${e.message})` }));
};

module.exports = connexionFCPlus;
