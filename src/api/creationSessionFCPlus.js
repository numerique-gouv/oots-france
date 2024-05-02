const creationSessionFCPlus = (config, requete, reponse) => {
  const { adaptateurChiffrement, adaptateurEnvironnement, adaptateurFranceConnectPlus } = config;

  const identifiantClient = adaptateurEnvironnement.identifiantClient();
  const urlRedirectionConnexion = adaptateurEnvironnement.urlRedirectionConnexion();
  const etat = adaptateurChiffrement.cleHachage(`${Math.random()}`);
  const nonce = adaptateurChiffrement.cleHachage(`${Math.random()}`);

  return adaptateurFranceConnectPlus.urlCreationSession()
    .then((url) => reponse.redirect(
      `${url}?scope=profile%20openid&acr_values=eidas2&claims={%22id_token%22:{%22amr%22:{%22essential%22:true}}}&prompt=login%20consent&response_type=code&idp_hint=${adaptateurEnvironnement.fournisseurIdentiteSuggere()}&client_id=${identifiantClient}&redirect_uri=${urlRedirectionConnexion}&state=${etat}&nonce=${nonce}`,
    ));
};

module.exports = creationSessionFCPlus;
