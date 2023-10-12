const Entete = require('../../src/ebms/entete');
const EnteteErreur = require('../../src/ebms/enteteErreur');

describe("L'entête EBMS d'une réponse-erreur", () => {
  it('connaît son action', () => {
    expect(EnteteErreur.action()).toEqual(Entete.REPONSE_ERREUR);
  });
});
