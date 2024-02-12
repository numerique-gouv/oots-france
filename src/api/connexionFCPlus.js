const connexionFCPlus = (config, code, requete, reponse) => {
  const { adaptateurChiffrement, adaptateurFranceConnectPlus } = config;

  return adaptateurFranceConnectPlus.recupereInfosUtilisateur(code)
    .then((infos) => adaptateurChiffrement.genereJeton(infos)
      .then((jwt) => {
        // eslint-disable-next-line no-param-reassign
        requete.session.jeton = jwt;
      })
      .then(() => reponse.json(infos)))
    .catch((e) => reponse.status(502).json({
      erreur: `Échec authentification (${e.message})`,
    }));
};

module.exports = connexionFCPlus;
