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

  it("connaît l'identifiant de la requête", () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecIdRequete('urn:uuid:12345678-1234-1234-1234-1234567890ab')
      .construis();
    const requete = new Requete(xmlParse);

    expect(requete.idRequete()).toBe('urn:uuid:12345678-1234-1234-1234-1234567890ab');
  });

  it('connaît le code de la démarche', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecCodeDemarche('UN_CODE')
      .construis();
    const requete = new Requete(xmlParse);

    expect(requete.codeDemarche()).toBe('UN_CODE');
  });

  it('connaît le requêteur', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecRequeteur({ id: '12345', nom: 'Un requêteur' })
      .construis();
    const requete = new Requete(xmlParse);

    expect(requete.requeteur().id).toBe('12345');
    expect(requete.requeteur().nom).toBe('Un requêteur');
  });

  it('connaît le requêteur, même si identifiant est un nombre', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecRequeteur({ id: 12345 })
      .construis();
    const requete = new Requete(xmlParse);

    expect(requete.requeteur().id).toBe('12345');
  });

  it('connaît le demandeur', () => {
    const xmlParse = new ConstructeurXMLParseRequeteRecue()
      .avecDemandeur({
        dateNaissance: '1992-10-22',
        identifiantEidas: 'DK/DE/123123123',
        nom: 'Dupont',
        prenom: 'Jean',
      })
      .construis();
    const requete = new Requete(xmlParse);

    const demandeur = requete.demandeur();
    expect(demandeur.dateNaissance).toBe('1992-10-22');
    expect(demandeur.identifiantEidas).toBe('DK/DE/123123123');
    expect(demandeur.nom).toBe('Dupont');
    expect(demandeur.prenom).toBe('Jean');
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

    it('ne joint pas de pièce justificative', () => {
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.DEMANDE_BOURSE_ETUDIANTE)
        .construis();
      const requete = new Requete(xmlParse);
      const reponseErreur = requete.reponse(config);

      expect(reponseErreur.pieceJointePresente()).toBe(false);
    });
  });

  describe('avec comme démarche une vérification système', () => {
    it('répond avec un message de vérification système avec pièce jointe', () => {
      adaptateurUUID.genereUUID = () => '12345678-1234-1234-1234-1234567890ab';
      const xmlParse = new ConstructeurXMLParseRequeteRecue()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .construis();
      const requete = new Requete(xmlParse);
      const reponse = requete.reponse(config, {});

      expect(reponse.pieceJointePresente()).toBe(true);
    });
  });
});
