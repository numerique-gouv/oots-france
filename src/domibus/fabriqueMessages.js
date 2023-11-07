const ReponseErreur = require('./reponseErreur');
const ReponseErreurAutorisationRequise = require('./reponseErreurAutorisationRequise');
const ReponseSucces = require('./reponseSucces');
const Requete = require('./requete');
const Entete = require('../ebms/entete');

const estReponseErreurAutorisationRequise = (xml) => (
  xml.QueryResponse['@_status'] === 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure'
    && xml.QueryResponse.Exception['@_type'] === 'rs:AuthorizationExceptionType'
);

const nouveauMessage = (action, corpsMessage) => {
  if (action === Entete.EXECUTION_REQUETE) {
    return new Requete(corpsMessage);
  }

  if (action === Entete.EXECUTION_REPONSE) {
    return new ReponseSucces(corpsMessage);
  }

  return estReponseErreurAutorisationRequise(corpsMessage)
    ? new ReponseErreurAutorisationRequise(corpsMessage)
    : new ReponseErreur(corpsMessage);
};

module.exports = { nouveauMessage };
