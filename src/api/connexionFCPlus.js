const connexionFCPlus = (config, code, requete, reponse) => {
  const { adaptateurFranceConnectPlus } = config;

  adaptateurFranceConnectPlus.recupereInfosUtilisateur(code)
    .then((infos) => reponse.json(infos))
    .catch((e) => reponse.status(502).json({
      erreur: `Échec authentification (${e.message})`,
    }));
};

module.exports = connexionFCPlus;
