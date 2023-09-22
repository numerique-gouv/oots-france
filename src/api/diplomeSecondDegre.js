const diplomeSecondDegre = (adaptateurDomibus, adaptateurUUID, requete, reponse) => {
  const idConversation = adaptateurUUID.genereUUID();
  const { destinataire } = requete.query;

  return adaptateurDomibus
    .envoieMessageRequete(destinataire, idConversation)
    .then(() => adaptateurDomibus.urlRedirectionDepuisReponse(idConversation))
    .then((urlRedirection) => {
      reponse.redirect(`${urlRedirection}?returnurl=${process.env.URL_OOTS_FRANCE}`);
    });
};

module.exports = diplomeSecondDegre;
