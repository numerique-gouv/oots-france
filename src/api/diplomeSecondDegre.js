const { ErreurAbsenceReponseDestinataire } = require('../erreurs');

const urlRedirection = (idConversation, adaptateurDomibus) => adaptateurDomibus
  .urlRedirectionDepuisReponse(idConversation)
  .then((url) => ({ urlRedirection: `${url}?returnurl=${process.env.URL_OOTS_FRANCE}` }));

const pieceJustificative = (idConversation, adaptateurDomibus) => adaptateurDomibus
  .pieceJustificativeDepuisReponse(idConversation)
  .then((pj) => ({ pieceJustificative: pj }));

const estErreurAbsenceReponseDestinataire = (e) => (
  e instanceof AggregateError
    && e.errors.every((erreur) => (erreur instanceof ErreurAbsenceReponseDestinataire))
);

const diplomeSecondDegre = (adaptateurDomibus, adaptateurUUID, requete, reponse) => {
  const idConversation = adaptateurUUID.genereUUID();
  const { destinataire } = requete.query;

  return adaptateurDomibus
    .envoieMessageRequete(destinataire, idConversation)
    .then(() => Promise.any([
      urlRedirection(idConversation, adaptateurDomibus),
      pieceJustificative(idConversation, adaptateurDomibus),
    ]))
    .then((resultat) => {
      if (resultat.urlRedirection) {
        reponse.redirect(resultat.urlRedirection);
      } else if (resultat.pieceJustificative) {
        reponse.send('Pièce justificative reçue !');
      }
    })
    .catch((e) => {
      if (estErreurAbsenceReponseDestinataire(e)) {
        reponse.status(504).send(e.errors.map((erreur) => erreur.message).join(' ; '));
      } else throw e;
    });
};

module.exports = diplomeSecondDegre;
