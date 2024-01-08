const ConstructeurXMLParseRequeteRecue = require('../constructeurs/constructeurXMLParseRequeteRecue');
const Requete = require('../../src/domibus/requete');
const CodeDemarche = require('../../src/ebms/codeDemarche');
const ReponseErreur = require('../../src/ebms/reponseErreur');

describe('Une action de requête reçue depuis Domibus', () => {
  const adaptateurUUID = {};
  const horodateur = {};
  const config = { adaptateurUUID, horodateur };

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => '';
    horodateur.maintenant = () => '';
  });

  it('connaît le code de la démarche', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecCodeDemarche('UN_CODE')
      .construis();
    const requete = new Requete(xmlParse);

    expect(requete.codeDemarche()).toBe('UN_CODE');
  });

  describe('avec comme démarche une demande de bourse', () => {
    it("transmets l'identifiant de la requête", () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis();
      const requete = new Requete(xmlParse);
      const reponse = requete.reponse(config, { idRequete: '12345' });

      expect(reponse.idRequete).toBe('12345');
    });

    it('répond avec une `ReponseErreur`', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis();
      const requete = new Requete(xmlParse);

      expect(requete.reponse(config)).toBeInstanceOf(ReponseErreur);
    });

    it('répond avec une erreur OBJECT_NOT_FOUND', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis();
      const requete = new Requete(xmlParse);
      const reponseErreur = requete.reponse(config);

      expect(reponseErreur.codeException).toBe('EDM:ERR:0004');
    });
  });

  describe('avec comme démarche une vérification système', () => {
    it('répond avec une erreur QUERY_EXCEPTION', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .construis();
      const requete = new Requete(xmlParse);
      const reponseErreur = requete.reponse(config);

      expect(reponseErreur.codeException).toBe('EDM:ERR:0008');
    });
  });
});
