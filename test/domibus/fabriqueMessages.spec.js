const FabriqueMessages = require('../../src/domibus/fabriqueMessages');
const ReponseErreur = require('../../src/domibus/reponseErreur');
const ReponseErreurAutorisationRequise = require('../../src/domibus/reponseErreurAutorisationRequise');
const ReponseSucces = require('../../src/domibus/reponseSucces');
const Requete = require('../../src/domibus/requete');
const Entete = require('../../src/ebms/entete');

describe('La fabrique de messages reçus', () => {
  it('sait créer une réponse en erreur avec autorisation requise', () => {
    const xmlParse = {
      QueryResponse: {
        '@_status': 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure',
        Exception: { '@_type': 'rs:AuthorizationExceptionType' },
      },
    };

    const message = FabriqueMessages.nouveauMessage(Entete.REPONSE_ERREUR, xmlParse);
    expect(message).toBeInstanceOf(ReponseErreurAutorisationRequise);
  });

  it('sait créer une réponse en erreur avec objet introuvable', () => {
    const xmlParse = {
      QueryResponse: {
        '@_status': 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Failure',
        Exception: { '@_type': 'rs:ObjectNotFoundExceptionType' },
      },
    };

    const message = FabriqueMessages.nouveauMessage(Entete.REPONSE_ERREUR, xmlParse);
    expect(message).toBeInstanceOf(ReponseErreur);
  });

  it('sait créer une requête', () => {
    const message = FabriqueMessages.nouveauMessage(Entete.EXECUTION_REQUETE);
    expect(message).toBeInstanceOf(Requete);
  });

  it('sait créer une réponse en succès', () => {
    const message = FabriqueMessages.nouveauMessage(Entete.EXECUTION_REPONSE);
    expect(message).toBeInstanceOf(ReponseSucces);
  });
});
