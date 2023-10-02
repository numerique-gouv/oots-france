const { ErreurAbsenceReponseDestinataire } = require('../erreurs');

const diplomeSecondDegre = (adaptateurDomibus, adaptateurUUID, requete, reponse) => {
  const idConversation = adaptateurUUID.genereUUID();
  const { destinataire } = requete.query;

  return adaptateurDomibus
    .envoieMessageRequete(destinataire, idConversation)
    .then((idMessage) => adaptateurDomibus.urlRedirectionDepuisReponse(idConversation, idMessage))
    .then((urlRedirection) => {
      reponse.redirect(`${urlRedirection}?returnurl=${process.env.URL_OOTS_FRANCE}`);
    })
    .catch((e) => {
      if (e instanceof ErreurAbsenceReponseDestinataire) {
        reponse.status(504).send(e.message);
      } else throw e;
    });
};

module.exports = diplomeSecondDegre;
