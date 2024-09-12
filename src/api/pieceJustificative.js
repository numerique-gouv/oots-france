const {
  ErreurAbsenceReponseDestinataire,
  ErreurEBMS,
  ErreurReponseRequete,
} = require('../erreurs');

const estErreurAbsenceReponse = (e) => e instanceof ErreurAbsenceReponseDestinataire;
const estErreurReponseRequete = (e) => e instanceof ErreurReponseRequete;
const estErreurMetier = (e) => estErreurAbsenceReponse(e) || estErreurReponseRequete(e);

const paramsRequete = (config, codeDemarche, codePays, idRequeteur) => {
  const { depotPointsAcces, depotRequeteurs, depotServicesCommuns } = config;

  return depotServicesCommuns.trouveTypesJustificatifsPourDemarche(codeDemarche)
    .then((tjs) => tjs[0])
    .then((tj) => depotServicesCommuns.trouveFournisseurs(tj.id, codePays)
      .then((fs) => fs[0])
      .then((f) => depotPointsAcces.trouvePointAcces(f.idPointAcces())
        .then((pa) => depotRequeteurs.trouveRequeteur(idRequeteur)
          .then((r) => ({
            destinataire: pa,
            fournisseur: f,
            requeteur: r,
            typeJustificatif: tj,
          })))));
};

const pieceJustificativeRecue = (idConversation, adaptateurDomibus) => adaptateurDomibus
  .pieceJustificativeDepuisReponse(idConversation)
  .then((pj) => ({ pieceJustificative: pj }));

const urlRedirection = (idConversation, adaptateurDomibus) => adaptateurDomibus
  .urlRedirectionDepuisReponse(idConversation)
  .then((url) => ({ urlRedirection: `${url}?returnurl=${process.env.URL_OOTS_FRANCE}` }));

const pieceJustificative = (config, requete, reponse) => {
  const {
    adaptateurDomibus,
    adaptateurUUID,
  } = config;
  const idConversation = adaptateurUUID.genereUUID();
  const {
    codeDemarche,
    codePays,
    idRequeteur,
    previsualisationRequise,
  } = requete.query;

  return paramsRequete(config, codeDemarche, codePays, idRequeteur)
    .then(({
      destinataire,
      fournisseur,
      requeteur,
      typeJustificatif,
    }) => {
      adaptateurDomibus.envoieMessageRequete({
        codeDemarche,
        destinataire,
        fournisseur,
        idConversation,
        requeteur,
        typeJustificatif,
        previsualisationRequise: (previsualisationRequise === 'true' || previsualisationRequise === ''),
      });
    })
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
      if (e instanceof ErreurEBMS) {
        reponse.status(422).json({ erreur: e.message });
      } else if (e instanceof AggregateError) {
        let codeStatus = 500;
        if (e.errors.every(estErreurAbsenceReponse)) {
          codeStatus = 504;
        } else if (e.errors.every(estErreurMetier)) {
          codeStatus = 502;
        }
        reponse.status(codeStatus).json({ erreur: e.errors.map((erreur) => erreur.message).join(' ; ') });
      } else throw e;
    });
};

module.exports = pieceJustificative;
