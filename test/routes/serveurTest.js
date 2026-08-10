const { ErreurAbsenceReponseDestinataire } = require('../../src/erreurs')
const OOTS_FRANCE = require('../../src/ootsFrance')
const Fournisseur = require('../../src/ebms/fournisseur')
const Requeteur = require('../../src/ebms/requeteur')
const TypeJustificatif = require('../../src/ebms/typeJustificatif')
const nouveauMiddleware = require('../../src/routes/middleware')
const depotJournalFactice = require('../constructeurs/depotJournalFactice')

const serveurTest = () => {
  let adaptateurChiffrement
  let adaptateurDomibus
  let adaptateurEnvironnement
  let adaptateurUUID
  let depotJournal
  let depotPointsAcces
  let depotRequeteurs
  let depotServicesCommuns
  let ecouteurDomibus
  let horodateur
  let middleware
  let transmetteurPiecesJustificatives

  let serveur

  const arrete = (suite) => {
    serveur.arreteEcoute(suite)
  }

  const initialise = (suite) => {
    adaptateurChiffrement = {
      cleHachage: () => '',
      dechiffreJWE: () => Promise.resolve({}),
      empreinteSha256: () => '',
    }

    adaptateurDomibus = {
      envoieMessageRequete: () => Promise.resolve({ idMessage: '', idRequete: '' }),
      urlRedirectionDepuisReponse: () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL reçue')),
      reponseAvecPieceJustificative: () => Promise.resolve({
        idRequeteur: () => '',
        pieceJustificative: () => Buffer.from(''),
      }),
    }

    adaptateurEnvironnement = {
      avecRequetePieceJustificative: () => true,
      urlOotsFrance: () => 'http://localhost:1234',
    }

    adaptateurUUID = {
      genereUUID: () => '',
    }

    depotJournal = depotJournalFactice()

    depotPointsAcces = {
      trouvePointAcces: () => Promise.resolve({}),
    }

    depotRequeteurs = {
      trouveRequeteur: () => Promise.resolve(new Requeteur({ adaptateurChiffrement })),
    }

    depotServicesCommuns = {
      trouveFournisseurs: () => Promise.resolve([new Fournisseur()]),
      trouveTypeJustificatif: () => Promise.resolve({}),
      trouveTypesJustificatifsPourDemarche: () => Promise.resolve([new TypeJustificatif()]),
    }

    ecouteurDomibus = {
      arreteEcoute: () => {},
      ecoute: () => {},
      etat: () => '',
    }

    horodateur = {
      maintenant: () => '',
    }

    transmetteurPiecesJustificatives = {
      envoie: () => Promise.resolve(),
    }

    middleware = nouveauMiddleware(adaptateurEnvironnement)

    serveur = OOTS_FRANCE.creeServeur({
      adaptateurDomibus,
      adaptateurChiffrement,
      adaptateurEnvironnement,
      adaptateurUUID,
      depotJournal,
      depotPointsAcces,
      depotRequeteurs,
      depotServicesCommuns,
      ecouteurDomibus,
      horodateur,
      middleware,
      transmetteurPiecesJustificatives,
    })

    serveur.ecoute(0, suite)
  }

  const port = () => serveur.port()

  return {
    adaptateurChiffrement: () => adaptateurChiffrement,
    adaptateurDomibus: () => adaptateurDomibus,
    adaptateurEnvironnement: () => adaptateurEnvironnement,
    adaptateurUUID: () => adaptateurUUID,
    arrete,
    depotJournal: () => depotJournal,
    depotPointsAcces: () => depotPointsAcces,
    depotRequeteurs: () => depotRequeteurs,
    depotServicesCommuns: () => depotServicesCommuns,
    ecouteurDomibus: () => ecouteurDomibus,
    horodateur: () => horodateur,
    transmetteurPiecesJustificatives: () => transmetteurPiecesJustificatives,
    initialise,
    port,
  }
}

module.exports = serveurTest
