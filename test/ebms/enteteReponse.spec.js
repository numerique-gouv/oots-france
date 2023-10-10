const Entete = require('../../src/ebms/entete');
const EnteteReponse = require('../../src/ebms/enteteReponse');

describe("L'entête d'une réponse", () => {
  it('connaît son action', () => {
    expect(EnteteReponse.action()).toEqual(Entete.EXECUTION_REPONSE);
  });
});
