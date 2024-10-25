const ConstructeurXMLParseReponseSuccesRecue = require('../constructeurs/constructeurXMLParseReponseSuccesRecue');
const ReponseSucces = require('../../src/domibus/reponseSucces');

describe('Une réponse avec pièce justificative reçue depuis Domibus', () => {
  it('connaît le requêteur', () => {
    const xmlParse = new ConstructeurXMLParseReponseSuccesRecue()
      .avecRequeteur({ id: '12345', nom: 'Un requêteur' })
      .construis();
    const reponse = new ReponseSucces(xmlParse);

    expect(reponse.requeteur().id).toBe('12345');
    expect(reponse.requeteur().nom).toBe('Un requêteur');
  });
});
