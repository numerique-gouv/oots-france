const consigneSansDerouter = require('../consigneSansDerouter')
const Entete = require('../ebms/entete')
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

// La méthode par laquelle l'espace de prévisualisation ramène l'usager. Les TDD
// admettent GET, PUT et POST et recommandent GET — la seule que sache produire
// la redirection HTTP par laquelle le portail le reprend.
const METHODE_RETOUR = 'GET'

// L'espace de prévisualisation reçoit l'adresse de retour et sa méthode en
// paramètres de requête, que les TDD nomment `returnurl` et `returnmethod`. Ils
// sont posés par `URLSearchParams`, qui les encode et respecte la requête que
// `PreviewLocation` porte déjà — une concaténation sur `?` la détruirait. Les
// TDD interdisent à cette adresse de porter elle-même ces deux noms : `set`
// écrase donc plutôt qu'il n'ajoute, et c'est la valeur du portail qui vaut.
const urlRedirectionRecue = (idConversation, config) => {
  // Lue avant la course : une configuration absente est notre faute, et doit se
  // voir tout de suite plutôt qu'au bout du délai d'attente de Domibus.
  const urlRetour = config.adaptateurEnvironnement.urlOotsFrance()

  return config.adaptateurDomibus
    .urlRedirectionDepuisReponse(idConversation)
    .then((url) => {
      let urlPrevisualisation
      try {
        urlPrevisualisation = new URL(url)
      }
      // L'adresse vient du correspondant étranger : illisible, elle ferait
      // sinon remonter au requêteur le message natif de `URL`, en anglais et
      // inclassable — donc un 500 là où l'échec vient d'en face.
      catch {
        throw new ErreurReponseRequete(`Adresse de prévisualisation reçue illisible : « ${url} ».`)
      }

      urlPrevisualisation.searchParams.set('returnurl', urlRetour)
      urlPrevisualisation.searchParams.set('returnmethod', METHODE_RETOUR)

      return { urlRedirection: urlPrevisualisation.toString() }
    })
}

const pieceJustificative = (config, requete, reponse) => {
  const {
    adaptateurChiffrement,
    adaptateurDomibus,
    adaptateurUUID,
    depotJournal,
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

  // Ce que la passerelle ne saura jamais : un refus prononcé ici ne produit
  // aucun message ebMS, donc aucune trace de son côté. L'article 17 demande
  // pourtant de journaliser les erreurs — d'où le témoin, qui distingue
  // l'échange refusé avant tout envoi de celui resté sans réponse, dont
  // `requete_emise` rend déjà compte.
  let requeteEmise = false

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
        .then(({ idMessage, idRequete }) => {
          requeteEmise = true

          // Sans ce rattrapage, un échec d'écriture renverrait un 500 au
          // requêteur, qui retenterait et ferait instruire deux fois le même
          // échange chez le fournisseur — alors que la requête est partie.
          return consigneSansDerouter(
            () => depotJournal.consigneRequeteEmise({
              actionEbms: Entete.EXECUTION_REQUETE,
              idConversation,
              idMessage,
              idRequete,
              idRequeteur,
              autoriteRequerante: requeteur.id,
              schemaAutoriteRequerante: requeteur.typeId,
              autoriteFournisseuse: fournisseur.pointAcces.id,
              schemaAutoriteFournisseuse: fournisseur.pointAcces.typeId,
              sujetJustificatif: b.identifiantPourJournal(),
              typeJustificatif: typeJustificatif.id,
              codeDemarche,
            }),
            `Requête émise sans trace au journal (conversation ${idConversation}, message ${idMessage})`,
          )
        })
    })
    .then(() => Promise.any([
      urlRedirectionRecue(idConversation, config),
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
          ])
            // La redirection est déjà partie : cet échec n'a plus personne à
            // qui être signifié.
            .then(() => consigneSansDerouter(
              () => depotJournal.consignePieceTransmise({
                idConversation,
                idRequeteur: id,
                typeMime: 'application/pdf',
                empreinteJustificatif: adaptateurChiffrement.empreinteSha256(pj),
              }),
              `Pièce transmise sans trace au journal (conversation ${idConversation}, requêteur ${id})`,
            )))
      }

      return undefined
    })
    .catch((e) => {
      // Un échange que la requête a quitté est déjà raconté par le journal :
      // `requete_emise` sans réponse dit l'expiration, `erreur_recue` dit le
      // refus du fournisseur. Seul le refus prononcé ici n'existerait nulle
      // part.
      const journalise = requeteEmise
        ? Promise.resolve()
        : consigneSansDerouter(
            () => depotJournal.consigneRequeteRefusee({
              idConversation,
              idRequeteur,
              codeDemarche,
              codeErreur: e.constructor.name,
            }),
            `Requête refusée sans trace au journal (conversation ${idConversation}, requêteur ${idRequeteur})`,
          )

      return journalise
        .then(() => {
          const journaliseLErreur = () => console.error(e.response?.data || e)

          // Une erreur survenue après la redirection — la transmission de la
          // pièce au requêteur échoue une fois celle-ci partie, par exemple —
          // n'a plus de réponse HTTP disponible. Écrire par-dessus lèverait
          // `ERR_HTTP_HEADERS_SENT` ici même, dans un `.then` que la route ne
          // rend pas à Express : la rejection orpheline emporterait le
          // processus.
          if (reponse.headersSent) {
            journaliseLErreur()
            return
          }

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
            journaliseLErreur()
            reponse.status(500).json({ erreur: 'Erreur interne' })
          }
        })
    })
}

module.exports = pieceJustificative
