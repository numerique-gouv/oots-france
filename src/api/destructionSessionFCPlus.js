const destructionSessionFCPlus = (config, requete, reponse) => {
  const {
    adaptateurChiffrement,
    adaptateurEnvironnement,
    adaptateurFranceConnectPlus,
  } = config;

  const { utilisateurCourant: { jwtSessionFCPlus } } = requete;
  const etat = adaptateurChiffrement.cleHachage(`${Math.random()}`);
  const urlRedirectionDeconnexion = adaptateurEnvironnement.urlRedirectionDeconnexion();

  adaptateurFranceConnectPlus.urlDestructionSession()
    .then((url) => reponse.redirect(
      `${url}?id_token_hint=${jwtSessionFCPlus}&state=${etat}&post_logout_redirect_uri=${urlRedirectionDeconnexion}`,
    ));
};

module.exports = destructionSessionFCPlus;
