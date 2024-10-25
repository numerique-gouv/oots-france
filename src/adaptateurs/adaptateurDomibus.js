const axios = require('axios');
const EventEmitter = require('node:events');

const {
  ErreurAbsenceReponseDestinataire,
  ErreurAucunMessageDomibusRecu,
} = require('../erreurs');
const InstructionSOAP = require('../domibus/instructionSOAP');
const { requeteListeMessagesEnAttente, requeteRecuperationMessage } = require('../domibus/requetes');
const Entete = require('../ebms/entete');
const RequeteJustificatif = require('../ebms/requeteJustificatif');

const urlBase = process.env.URL_BASE_DOMIBUS;
const REPONSE_REDIRECTION_PREVISUALISATION = 'reponseRedirectionPrevisualisation';
const REPONSE_SUCCES = 'reponseSucces';

const AdaptateurDomibus = (config = {}) => {
  const annonceur = new EventEmitter();

  const enteteAuthentificationBasique = () => {
    const jetonEncode = btoa(`${process.env.LOGIN_API_REST}:${process.env.MOT_DE_PASSE_API_REST}`);
    return { Authorization: `Basic ${jetonEncode}` };
  };

  const envoieRequeteREST = (chemin, parametres) => axios({
    method: 'get',
    url: `${urlBase}/${chemin}`,
    headers: enteteAuthentificationBasique(),
    params: parametres,
  })
    .then(({ data }) => data);

  const envoieRequeteSOAP = (instruction, message) => axios.post(
    `${urlBase}/services/wsplugin/${instruction.libelle}`,
    message,
    { headers: { 'Content-Type': 'text/xml', ...enteteAuthentificationBasique() } },
  )
    .then(({ data }) => instruction.nouvelleReponseDomibus(data));

  const envoieMessageDomibus = (...args) => envoieRequeteSOAP(
    InstructionSOAP.envoieMessage(),
    ...args,
  );

  const recupereIdMessageSuivant = (identifiantConversation) => envoieRequeteSOAP(
    InstructionSOAP.listeMessagesEnAttente(),
    requeteListeMessagesEnAttente(identifiantConversation),
  )
    .then((reponse) => {
      if (reponse.messageEnAttente()) {
        return reponse.idMessageSuivant();
      }
      return Promise.reject(new ErreurAucunMessageDomibusRecu());
    });

  const recupereMessage = (idMessage) => envoieRequeteSOAP(
    InstructionSOAP.recupereMessage(),
    requeteRecuperationMessage(idMessage),
  );

  const repondsA = (requete) => {
    const message = requete.reponse(config);
    envoieMessageDomibus(message.enSOAP());
  };

  const traiteMessageSuivant = () => recupereIdMessageSuivant()
    .then((idMessage) => recupereMessage(idMessage))
    .then((message) => {
      if (message.action() === Entete.REPONSE_ERREUR) {
        annonceur.emit(REPONSE_REDIRECTION_PREVISUALISATION, message);
      } else if (message.action() === Entete.EXECUTION_REPONSE) {
        annonceur.emit(REPONSE_SUCCES, message);
      } else if (message.action() === Entete.EXECUTION_REQUETE) {
        repondsA(message);
      }
    })
    .catch((e) => {
      if (!(e instanceof ErreurAucunMessageDomibusRecu)) {
        /* eslint-disable no-console */

        console.error(e.response?.data || e);

        /* eslint-enable no-console */
      }
    });

  const envoieMessageRequete = (donnees) => {
    const requeteJustificatif = new RequeteJustificatif(config, donnees);

    return envoieMessageDomibus(requeteJustificatif.enSOAP())
      .then((reponse) => reponse.idMessage());
  };

  const urlRedirectionDepuisReponse = (idConversation) => new Promise(
    (resolve, reject) => {
      annonceur.on(REPONSE_REDIRECTION_PREVISUALISATION, (reponse) => {
        if (idConversation === reponse.idConversation()) {
          try {
            resolve(reponse.suiteConversation());
          } catch (e) {
            reject(e);
          }
        }
      });

      setTimeout(() => {
        reject(new ErreurAbsenceReponseDestinataire('aucune URL de redirection reçue'));
      }, process.env.DELAI_MAX_ATTENTE_DOMIBUS);
    },
  );

  const reponseAvecPieceJustificative = (idConversation) => new Promise(
    (resolve, reject) => {
      annonceur.on(REPONSE_SUCCES, (reponse) => {
        if (idConversation === reponse.idConversation()) { resolve(reponse); }
      });

      setTimeout(() => {
        reject(new ErreurAbsenceReponseDestinataire('aucune pièce justificative reçue'));
      }, process.env.DELAI_MAX_ATTENTE_DOMIBUS);
    },
  );

  const trouvePointAcces = (nomPointAcces) => envoieRequeteREST('ext/party', { name: nomPointAcces });

  return {
    envoieMessageRequete,
    reponseAvecPieceJustificative,
    traiteMessageSuivant,
    trouvePointAcces,
    urlRedirectionDepuisReponse,
  };
};

module.exports = AdaptateurDomibus;
