const { ErreurAbsenceReponseDestinataire, ErreurReponseRequete, ErreurDestinataireInexistant } = require('../erreurs');

const urlRedirection = (idConversation, adaptateurDomibus) => adaptateurDomibus
  .urlRedirectionDepuisReponse(idConversation)
  .then((url) => ({ urlRedirection: `${url}?returnurl=${process.env.URL_OOTS_FRANCE}` }));

const pieceJustificativeRecue = (idConversation, adaptateurDomibus) => adaptateurDomibus
  .pieceJustificativeDepuisReponse(idConversation)
  .then((pj) => ({ pieceJustificative: pj }));

const estErreurAbsenceReponse = (e) => e instanceof ErreurAbsenceReponseDestinataire;
const estErreurReponseRequete = (e) => e instanceof ErreurReponseRequete;
const estErreurMetier = (e) => estErreurAbsenceReponse(e) || estErreurReponseRequete(e);

const pieceJustificative = (adaptateurDomibus, adaptateurUUID, requete, reponse) => {
  const idConversation = adaptateurUUID.genereUUID();
  const { destinataire, previsualisationRequise } = requete.query;

  return adaptateurDomibus
    .verifieDestinataireExiste(destinataire)
    .then(() => adaptateurDomibus.envoieMessageRequete({
      destinataire,
      idConversation,
      previsualisationRequise: (previsualisationRequise === 'true' || previsualisationRequise === ''),
    }))
    .then(() => Promise.any([
      urlRedirection(idConversation, adaptateurDomibus),
      pieceJustificativeRecue(idConversation, adaptateurDomibus),
    ]))
    .then((resultat) => {
      if (resultat.urlRedirection) {
        reponse.redirect(resultat.urlRedirection);
      } else if (resultat.pieceJustificative) {
        reponse.set({ 'content-type': 'application/pdf; charset=utf-8' });
        reponse.send(resultat.pieceJustificative);
      }
    })
    .catch((e) => {
      if (e instanceof ErreurDestinataireInexistant) {
        reponse.status(422).send(e.message);
      } else if (e instanceof AggregateError) {
        let codeStatus = 500;
        if (e.errors.every(estErreurAbsenceReponse)) {
          codeStatus = 504;
        } else if (e.errors.every(estErreurMetier)) {
          codeStatus = 502;
        }
        reponse.status(codeStatus).send(e.errors.map((erreur) => erreur.message).join(' ; '));
      } else throw e;
    });
};

module.exports = pieceJustificative;
