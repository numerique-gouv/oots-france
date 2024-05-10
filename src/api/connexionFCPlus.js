const stockeDansCookieSession = (infos, adaptateurChiffrement, requete) => adaptateurChiffrement
  .genereJeton(infos)
  .then((jwt) => { requete.session.jeton = jwt; });

const redirigeDepuisNavigateur = (destination, reponse) => reponse.send(`
<!DOCTYPE html>
<html>
<head><meta http-equiv="refresh" content="0; url='${destination}'"></head>
<body></body>
</html>
`);

const connexionFCPlus = (config, code, requete, reponse) => {
  const { adaptateurChiffrement, fabriqueSessionFCPlus } = config;

  requete.session.jeton = undefined;

  return fabriqueSessionFCPlus.nouvelleSession(code)
    .then((session) => session.enJSON())
    .then((infos) => stockeDansCookieSession(infos, adaptateurChiffrement, requete))
    .then(() => redirigeDepuisNavigateur('/', reponse))
    .catch((e) => reponse.status(502).json({ erreur: `Échec authentification (${e.message})` }));
};

module.exports = connexionFCPlus;
