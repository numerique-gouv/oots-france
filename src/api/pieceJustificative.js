const {
  ErreurAbsenceReponseDestinataire,
  ErreurEBMS,
  ErreurJetonInvalide,
  ErreurReponseRequete,
} = require('../erreurs')

const estErreurAbsenceReponse = e => e instanceof ErreurAbsenceReponseDestinataire
const estErreurReponseRequete = e => e instanceof ErreurReponseRequete
const estErreurMetier = e => estErreurAbsenceReponse(e) || estErreurReponseRequete(e)

const paramsRequete = (beneficiaireChiffre, config, codeDemarche, codePays, idRequeteur) => {
  const { depotPointsAcces, depotRequeteurs, depotServicesCommuns } = config

  return depotServicesCommuns.trouveTypesJustificatifsPourDemarche(codeDemarche)
    .then(tjs => tjs[0])
    .then(tj => depotServicesCommuns.trouveFournisseurs(tj.id, codePays)
      .then(fs => fs[0])
      .then(f => depotPointsAcces.trouvePointAcces(f.idPointAcces())
        .then(pa => depotRequeteurs.trouveRequeteur(idRequeteur)
          .then(r => r.beneficiaire(beneficiaireChiffre)
            .then(b => ({
              beneficiaire: b,
              destinataire: pa,
              fournisseur: f,
              requeteur: r,
              typeJustificatif: tj,
            }))))))
}

const pieceJustificativeRecue = (idConversation, adaptateurDomibus) => adaptateurDomibus
  .reponseAvecPieceJustificative(idConversation)
  .then(reponse => ({ reponseAvecPieceJustificative: reponse }))

const urlRedirectionRecue = (idConversation, adaptateurDomibus) => adaptateurDomibus
  .urlRedirectionDepuisReponse(idConversation)
  .then(url => ({ urlRedirection: `${url}?returnurl=${process.env.URL_OOTS_FRANCE}` }))

const pieceJustificative = (config, requete, reponse) => {
  const {
    adaptateurDomibus,
    adaptateurUUID,
    depotRequeteurs,
    transmetteurPiecesJustificatives,
  } = config
  const idConversation = adaptateurUUID.genereUUID()
  const {
    beneficiaire,
    codeDemarche,
    codePays,
    idRequeteur,
    previsualisationRequise,
  } = requete.query

  return paramsRequete(beneficiaire, config, codeDemarche, codePays, idRequeteur)
    .then(({
      beneficiaire: b,
      destinataire,
      fournisseur,
      requeteur,
      typeJustificatif,
    }) => {
      // La promesse est rendue : abandonnée, son échec — un refus de Domibus,
      // par exemple — n'atteindrait pas le `catch` de la chaîne et emporterait
      // le processus.
      return adaptateurDomibus.envoieMessageRequete({
        beneficiaire: b,
        codeDemarche,
        destinataire,
        fournisseur,
        idConversation,
        requeteur,
        typeJustificatif,
        previsualisationRequise: (previsualisationRequise === 'true' || previsualisationRequise === ''),
      })
    })
    .then(() => Promise.any([
      urlRedirectionRecue(idConversation, adaptateurDomibus),
      pieceJustificativeRecue(idConversation, adaptateurDomibus),
    ]))
    .then(({ reponseAvecPieceJustificative, urlRedirection }) => {
      if (urlRedirection) {
        reponse.redirect(urlRedirection)
      }
      else if (reponseAvecPieceJustificative) {
        const id = reponseAvecPieceJustificative.idRequeteur()
        const pj = reponseAvecPieceJustificative.pieceJustificative()

        // Rendue, comme les autres : abandonnée, une erreur de transmission
        // au requêteur échapperait au `catch` et emporterait le processus.
        return depotRequeteurs.trouveRequeteur(id)
          .then(({ url }) => Promise.all([
            transmetteurPiecesJustificatives.envoie(pj, url),
            reponse.redirect(`${url}/oots/callback`),
          ]))
      }

      return undefined
    })
    .catch((e) => {
      if (e instanceof ErreurEBMS || e instanceof ErreurJetonInvalide) {
        reponse.status(422).json({ erreur: e.message })
      }
      else if (e instanceof AggregateError) {
        let codeStatus = 500
        if (e.errors.every(estErreurAbsenceReponse)) {
          codeStatus = 504
        }
        else if (e.errors.every(estErreurMetier)) {
          codeStatus = 502
        }
        reponse.status(codeStatus).json({ erreur: e.errors.map(erreur => erreur.message).join(' ; ') })
      }
      else {
        // Relancée, l'erreur ne serait rattrapée par personne — la route ne
        // rend pas cette promesse à Express — et tuerait le processus. Le
        // détail reste au journal plutôt que de partir au requêteur.
        console.error(e.response?.data || e)
        reponse.status(500).json({ erreur: 'Erreur interne' })
      }
    })
}

module.exports = pieceJustificative
