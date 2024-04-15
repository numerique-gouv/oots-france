const connexionFCPlus = (config, code, requete, reponse) => {
  const { adaptateurChiffrement, fabriqueSessionFCPlus } = config;

  requete.session.jeton = undefined;

  return fabriqueSessionFCPlus.nouvelleSession(code)
    .then((session) => session.enJSON())
    .then((infos) => adaptateurChiffrement.genereJeton(infos)
      .then((jwt) => { requete.session.jeton = jwt; })
      .then(() => reponse.json(infos)))
    .catch((e) => reponse.status(502).json({ erreur: `Échec authentification (${e.message})` }));
};

module.exports = connexionFCPlus;
