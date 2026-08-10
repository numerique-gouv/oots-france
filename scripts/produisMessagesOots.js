// Produit un exemplaire de chaque message OOTS, corps et entête ebMS, avec les
// classes du dépôt, pour que scripts/valideSchematron.sh les confronte aux
// règles des TDD. Les valeurs sont fictives mais réalistes : seule la structure
// est validée.
const fs = require('fs')
const path = require('path')

const adaptateurEnvironnement = require('../src/adaptateurs/adaptateurEnvironnement')
const Fournisseur = require('../src/ebms/fournisseur')
const PersonnePhysique = require('../src/ebms/personnePhysique')
const PointAcces = require('../src/ebms/pointAcces')
const ReponseErreur = require('../src/ebms/reponseErreur')
const ReponseVerificationSysteme = require('../src/ebms/reponseVerificationSysteme')
const RequeteJustificatif = require('../src/ebms/requeteJustificatif')
const Requeteur = require('../src/ebms/requeteur')
const TypeJustificatif = require('../src/ebms/typeJustificatif')

process.env.SUFFIXE_IDENTIFIANTS_DOMIBUS ||= 'oots.eu'
process.env.IDENTIFIANT_EXPEDITEUR_DOMIBUS ||= 'AP_FR_01'
process.env.TYPE_IDENTIFIANT_EXPEDITEUR_DOMIBUS ||= 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots'
process.env.IDENTIFIANT_FOURNISSEUR_FRANCAIS ||= '00000000000001'
process.env.NOM_FOURNISSEUR_FRANCAIS ||= 'Direction interministérielle du numérique'

const destination = process.argv[2]

// Construit comme le fait `server.js`, en traversant l'accesseur qui valide
// l'environnement : les règles Schematron couvrent ainsi le chemin réellement
// emprunté en production, et pas une identité forgée pour l'occasion.
const fournisseurFrancais = Fournisseur.francais(adaptateurEnvironnement.identiteFournisseurFrancais())

let compteur = 0
const config = {
  fournisseurFrancais,
  adaptateurUUID: {
    genereUUID: () => `1a2b3c4d-0000-4000-8000-${String(compteur++).padStart(12, '0')}`,
  },
  horodateur: { maintenant: () => '2026-08-06T10:00:00.000Z' },
}

const requeteur = new Requeteur({}, {
  id: '00000000000002',
  nom: 'Ministère de l\'enseignement supérieur',
})

const fournisseurAllemand = new Fournisseur({
  pointAcces: { id: 'DE73524311', typeId: 'urn:cef.eu:names:identifier:EAS:9930' },
  descriptions: { EN: 'Civil Registration Office Berlin I' },
})

const beneficiaire = new PersonnePhysique({
  dateNaissance: '1992-10-22',
  identifiantEidas: 'FR/DE/123123123',
  nom: 'Dupont',
  prenom: 'Jean',
})

const typeJustificatif = new TypeJustificatif({
  id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
  descriptions: { EN: 'Certificate of Birth' },
  formatDistribution: 'application/pdf',
})

const destinataire = new PointAcces('AP_DE_01', 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots')
const idRequete = 'urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797'

// Renseigné sur chaque message comme il l'est en production : sans lui la
// balise `eb:ConversationId` est omise, et la règle qui exige un UUID
// (R-EDM-ebMS-017) ne s'exercerait sur rien.
const idConversation = 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b24'

const messages = {
  requete: new RequeteJustificatif(config, {
    beneficiaire,
    codeDemarche: 'T3',
    destinataire,
    fournisseur: fournisseurAllemand,
    idConversation,
    requeteur,
    typeJustificatif,
  }),
  reponse: new ReponseVerificationSysteme(config, {
    beneficiaire,
    destinataire,
    idConversation,
    idRequete,
    requeteur,
    typeJustificatif,
  }),
  // Un exemplaire par code que le dépôt émet : le type d'exception change avec
  // le code, et les règles le contraignent — un code jamais produit ici est un
  // code jamais confronté aux règles.
  erreur: new ReponseErreur(config, {
    destinataire,
    exception: ReponseErreur.OBJECT_NOT_FOUND_EXCEPTION,
    idConversation,
    idRequete,
    requeteur,
  }),
  erreurRequeteInvalide: new ReponseErreur(config, {
    destinataire,
    exception: ReponseErreur.INVALID_REQUEST_EXCEPTION,
    idConversation,
    idRequete,
    requeteur,
  }),
  erreurCapaciteNonSupportee: new ReponseErreur(config, {
    destinataire,
    exception: ReponseErreur.UNSUPPORTED_CAPABILITY_EXCEPTION,
    idConversation,
    idRequete,
    requeteur,
  }),
}

// L'entête ebMS est écrite à part : elle relève de sa propre règle, et le corps
// du message ne la contient pas — sur le fil, c'est l'enveloppe SOAP soumise à
// Domibus qui les réunit.
Object.entries(messages).forEach(([nom, message]) => {
  fs.writeFileSync(path.join(destination, `${nom}.xml`), message.corpsMessageEnXML())
  fs.writeFileSync(path.join(destination, `${nom}.entete.xml`), message.entete.enXML().trim())
})
