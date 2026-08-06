const express = require('express')

const EnteteErreur = require('../ebms/enteteErreur')
const EnteteRequete = require('../ebms/enteteRequete')
const Fournisseur = require('../ebms/fournisseur')
const PersonnePhysique = require('../ebms/personnePhysique')
const PointAcces = require('../ebms/pointAcces')
const ReponseErreur = require('../ebms/reponseErreur')
const ReponseVerificationSysteme = require('../ebms/reponseVerificationSysteme')
const RequeteJustificatif = require('../ebms/requeteJustificatif')
const Requeteur = require('../ebms/requeteur')
const TypeJustificatif = require('../ebms/typeJustificatif')

// Identités fictives partagées par les routes de démonstration, pour que
// l'entête et le message servis côte à côte décrivent le même échange.
const REQUETEUR_DEMONSTRATION = new Requeteur({}, { id: '00000000000002', nom: 'Un requêteur' })
const FOURNISSEUR_DEMONSTRATION = Fournisseur.francais({ id: '00000000000001', nom: 'Un fournisseur' })

const routesEbms = (config) => {
  const { adaptateurUUID, horodateur } = config

  const routes = express.Router()

  const sersXMLEntete = (ClasseEntete, { emetteurOriginal, destinataireFinal }, reponse) => {
    const destinataire = new PointAcces(
      process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS,
      process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS,
    )
    const idConversation = adaptateurUUID.genereUUID()
    const suffixe = process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS
    const idPayload = `cid:${adaptateurUUID.genereUUID()}@${suffixe}`
    const enteteEBMS = new ClasseEntete(
      { adaptateurUUID, horodateur },
      {
        destinataire, idConversation, idPayload, emetteurOriginal, destinataireFinal,
      },
    )

    reponse.set('Content-Type', 'text/xml')
    reponse.send(enteteEBMS.enXML())
  }

  // Les coins s'inversent selon le sens du message : sur la requête, le
  // requêteur français demande à un fournisseur étranger ; sur la réponse
  // d'erreur, le fournisseur français répond au requêteur qui l'a sollicité.
  routes.get('/entetes/requeteJustificatif', (_, reponse) => sersXMLEntete(
    EnteteRequete,
    {
      emetteurOriginal: REQUETEUR_DEMONSTRATION.identiteEbms(),
      destinataireFinal: FOURNISSEUR_DEMONSTRATION.identiteEbms(),
    },
    reponse,
  ))

  routes.get('/messages/requeteJustificatif', (_requete, reponse) => {
    const requeteJustificatif = new RequeteJustificatif(
      { adaptateurUUID, horodateur },
      { fournisseur: FOURNISSEUR_DEMONSTRATION, requeteur: REQUETEUR_DEMONSTRATION },
    )

    reponse.set('Content-Type', 'text/xml')
    reponse.send(requeteJustificatif.corpsMessageEnXML())
  })

  routes.get('/entetes/reponseErreur', (_, reponse) => sersXMLEntete(
    EnteteErreur,
    {
      emetteurOriginal: FOURNISSEUR_DEMONSTRATION.identiteEbms(),
      destinataireFinal: REQUETEUR_DEMONSTRATION.identiteEbms(),
    },
    reponse,
  ))

  routes.get('/messages/reponseErreur', (requete, reponse) => {
    const reponseErreur = new ReponseErreur({ adaptateurUUID, horodateur }, {
      idRequete: adaptateurUUID.genereUUID(),
      exception: ReponseErreur.OBJECT_NOT_FOUND_EXCEPTION,
      fournisseur: FOURNISSEUR_DEMONSTRATION,
      requeteur: REQUETEUR_DEMONSTRATION,
    })
    reponse.set('Content-Type', 'text/xml')
    reponse.send(reponseErreur.corpsMessageEnXML())
  })

  routes.get('/messages/reponseJustificatif', (requete, reponse) => {
    const beneficiaire = new PersonnePhysique({ dateNaissance: '1992-10-22', nom: 'Dupont', prenom: 'Jean' })
    const typeJustificatif = new TypeJustificatif({
      id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/12345678-1234-1234-1234-1234567890ab',
      descriptions: { EN: 'Some Evidence Type' },
    })
    const reponseJustificatif = new ReponseVerificationSysteme({ adaptateurUUID, horodateur }, {
      beneficiaire,
      destinataire: new PointAcces('unTypeIdentifiant', 'unIdentifiant'),
      fournisseur: FOURNISSEUR_DEMONSTRATION,
      idRequete: '12345678-1234-1234-1234-1234567890ab',
      idConversation: '12345',
      requeteur: REQUETEUR_DEMONSTRATION,
      typeJustificatif,
    })
    reponse.set('Content-Type', 'text/xml')
    reponse.send(reponseJustificatif.corpsMessageEnXML())
  })

  return routes
}

module.exports = routesEbms
