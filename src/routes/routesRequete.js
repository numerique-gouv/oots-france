const express = require('express')

const pieceJustificative = require('../api/pieceJustificative')

const routesRequete = (config) => {
  const {
    adaptateurChiffrement,
    adaptateurDomibus,
    adaptateurUUID,
    depotJournal,
    depotPointsAcces,
    depotRequeteurs,
    depotServicesCommuns,
    middleware,
    transmetteurPiecesJustificatives,
  } = config

  const routes = express.Router()

  routes.get(
    '/pieceJustificative',
    middleware.verifieInterrupteurOOTS,
    middleware.verifieBeneficiaire,
    (requete, reponse) => {
      pieceJustificative(
        {
          adaptateurChiffrement,
          adaptateurDomibus,
          adaptateurUUID,
          depotJournal,
          depotPointsAcces,
          depotRequeteurs,
          depotServicesCommuns,
          transmetteurPiecesJustificatives,
        },
        requete,
        reponse,
      )
    },
  )

  return routes
}

module.exports = routesRequete
