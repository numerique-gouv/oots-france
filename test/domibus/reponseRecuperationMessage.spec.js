const ConstructeurEnveloppeSOAPAvecPieceJointe = require('../constructeurs/constructeurEnveloppeSOAPAvecPieceJointe')
const ConstructeurEnveloppeSOAPException = require('../constructeurs/constructeurEnveloppeSOAPException')
const ConstructeurEnveloppeSOAPRequete = require('../constructeurs/constructeurEnveloppeSOAPRequete')
const ReponseErreurAutorisationRequise = require('../../src/domibus/reponseErreurAutorisationRequise')
const ReponseRecuperationMessage = require('../../src/domibus/reponseRecuperationMessage')
const CodeDemarche = require('../../src/ebms/codeDemarche')
const Fournisseur = require('../../src/ebms/fournisseur')
const PointAcces = require('../../src/ebms/pointAcces')
const { ErreurReponseRequete, ErreurMessageIllisible } = require('../../src/erreurs')

describe('La réponse à une requête Domibus de récupération de message', () => {
  const fournisseurFrancais = Fournisseur.francais({ id: '00000000000001', nom: 'Un fournisseur français' })

  it('connaît l\'URL de redirection spécifiée', () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecURLRedirection('https://example.com/preview/12345678-1234-1234-1234-1234567890ab')
      .construis()
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP)

    expect(reponse.corpsMessage).toBeInstanceOf(ReponseErreurAutorisationRequise)
    expect(reponse.suiteConversation()).toEqual('https://example.com/preview/12345678-1234-1234-1234-1234567890ab')
  })

  it('connaît le type d\'action liée au message', () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .construis()
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP)

    expect(reponse.action()).toEqual('ExceptionResponse')
  })

  it('connaît l\'identifiant de la conversation', () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecIdConversation('12345678-1234-1234-1234-1234567890ab')
      .construis()
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP)

    expect(reponse.idConversation()).toEqual('12345678-1234-1234-1234-1234567890ab')
  })

  it('connaît l\'expéditeur', () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecExpediteur(new PointAcces('unIdentifiant', 'unType'))
      .construis()
    const reponse = new ReponseRecuperationMessage(enveloppeSOAP)

    expect(reponse.expediteur().id).toEqual('unIdentifiant')
    expect(reponse.expediteur().typeId).toEqual('unType')
  })

  it('connaît son identifiant de payload du message EBMS', () => {
    const enveloppeSOAP = ConstructeurEnveloppeSOAPException.erreurAutorisationRequise()
      .avecIdPayload('cid:11111111-1111-1111-1111-111111111111@oots.eu')
      .construis()

    const reponse = new ReponseRecuperationMessage(enveloppeSOAP)
    expect(reponse.idsPayloads['application/x-ebrs+xml']).toEqual('cid:11111111-1111-1111-1111-111111111111@oots.eu')
  })

  it('sait extraire une pièce jointe', () => {
    const enveloppeSOAP = new ConstructeurEnveloppeSOAPAvecPieceJointe()
      .avecPieceJointe('cid:12345678-1234-1234-1234-1234567890ab@pdf.oots.eu', 'application/pdf', 'abcd')
      .construis()

    const reponse = new ReponseRecuperationMessage(enveloppeSOAP)
    const contenuPieceJustificative = reponse.pieceJustificative().toString()
    expect(contenuPieceJustificative).toEqual('abcd')
  })

  describe('dans le cas d\'une réponse en erreur pièce inexistante', () => {
    it('lève une erreur à la tentative de lecture de l\'URL de redirection', (suite) => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPException()
        .avecErreur({
          type: 'rs:ObjectNotFoundExceptionType',
          code: 'EDM:ERR:0004',
          message: 'Object not found',
          severite: 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error',
        })
        .construis()
      const reponse = new ReponseRecuperationMessage(enveloppeSOAP)

      try {
        reponse.suiteConversation()
        suite('Une `ErreurReponseRequete` aurait dû être levée.')
      }
      catch (e) {
        expect(e).toBeInstanceOf(ErreurReponseRequete)
        expect(e.message).toEqual('EDM:ERR:0004 : Object not found')
        suite()
      }
    })

    it('se contente du libellé quand l\'erreur reçue ne porte pas de code', (suite) => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPException()
        .avecErreur({
          type: 'rs:ObjectNotFoundExceptionType',
          message: 'Object not found',
          severite: 'urn:oasis:names:tc:ebxml-regrep:ErrorSeverityType:Error',
        })
        .sansCode()
        .construis()
      const reponse = new ReponseRecuperationMessage(enveloppeSOAP)

      try {
        reponse.suiteConversation()
        suite('Une `ErreurReponseRequete` aurait dû être levée.')
      }
      catch (e) {
        expect(e.message).toEqual('Object not found')
        suite()
      }
    })
  })

  describe('dans le cas d\'une requête de pièce justificative', () => {
    it('connaît le code de la démarche', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .construis()

      const reponse = new ReponseRecuperationMessage(enveloppeSOAP)
      expect(reponse.codeDemarche()).toBe(CodeDemarche.VERIFICATION_SYSTEME)
    })

    it('fait écho à l\'identifiant d\'échange de la requête', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .avecIdEchange('22222222-2222-2222-2222-222222222222')
        .construis()

      const reponse = new ReponseRecuperationMessage(enveloppeSOAP).reponse({
        adaptateurUUID: { genereUUID: () => '11111111-1111-1111-1111-111111111111' },
        fournisseurFrancais,
        horodateur: { maintenant: () => '' },
      })

      expect(reponse.entete.idEchange).toBe('22222222-2222-2222-2222-222222222222')
    })

    it('connaît son identifiant de requête', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecIdRequete('urn:uuid:11111111-1111-1111-1111-111111111111')
        .construis()
      const reponse = new ReponseRecuperationMessage(enveloppeSOAP)

      expect(reponse.idRequete()).toEqual('urn:uuid:11111111-1111-1111-1111-111111111111')
    })

    it('connaît le requêteur', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .avecRequeteur({ id: '12345', nom: 'Un requêteur' })
        .construis()

      const reponse = new ReponseRecuperationMessage(enveloppeSOAP)
      expect(reponse.requeteur().id).toBe('12345')
      expect(reponse.requeteur().nom).toBe('Un requêteur')
    })

    it('transmet le requêteur à la réponse', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .avecRequeteur({ id: '12345', nom: 'Un requêteur' })
        .construis()

      const reponseVerificationSysteme = new ReponseRecuperationMessage(enveloppeSOAP).reponse({
        adaptateurUUID: { genereUUID: () => '' },
        fournisseurFrancais,
      })

      const { requeteur } = reponseVerificationSysteme
      expect(requeteur.id).toBe('12345')
      expect(requeteur.nom).toBe('Un requêteur')
    })

    it('répond une erreur `EDM:ERR:0003` quand un slot attendu manque', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .sansSlot('Procedure')
        .construis()

      const reponseErreur = new ReponseRecuperationMessage(enveloppeSOAP).reponse({
        adaptateurUUID: { genereUUID: () => '' },
        fournisseurFrancais,
        horodateur: { maintenant: () => '' },
      })

      expect(reponseErreur.codeException).toBe('EDM:ERR:0003')
      expect(reponseErreur.typeException).toBe('rs:InvalidRequestExceptionType')
    })

    it('renonce à répondre quand le requêteur lui-même est illisible', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .sansSlot('EvidenceRequester')
        .construis()
      const requeteRecue = new ReponseRecuperationMessage(enveloppeSOAP)

      expect(() => requeteRecue.reponse({
        adaptateurUUID: { genereUUID: () => '' },
        fournisseurFrancais,
        horodateur: { maintenant: () => '' },
      })).toThrow(ErreurMessageIllisible)
    })

    it('connaît le bénéficiaire', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .avecDemandeur({ nom: 'Dupont' })
        .construis()

      const reponse = new ReponseRecuperationMessage(enveloppeSOAP)
      expect(reponse.beneficiaire().nom).toBe('Dupont')
    })

    it('transmet le bénéficiaire à la réponse', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .avecDemandeur({ nom: 'Dupont' })
        .construis()

      const reponseVerificationSysteme = new ReponseRecuperationMessage(enveloppeSOAP).reponse({
        adaptateurUUID: { genereUUID: () => '' },
        fournisseurFrancais,
      })
      expect(reponseVerificationSysteme.beneficiaire.nom).toEqual('Dupont')
    })

    it('connaît le type de justificatif demandé', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .avecTypeJustificatif({ id: 'abcdef', descriptions: { FR: 'Un type de justificatif' } })
        .construis()

      const reponse = new ReponseRecuperationMessage(enveloppeSOAP)
      expect(reponse.typeJustificatif().id).toBe('abcdef')
    })

    it('transmet le type de justificatif à la réponse', () => {
      const enveloppeSOAP = new ConstructeurEnveloppeSOAPRequete()
        .avecCodeDemarche(CodeDemarche.VERIFICATION_SYSTEME)
        .avecTypeJustificatif({ id: 'abcdef', descriptions: { FR: 'Un type de justificatif' } })
        .construis()

      const reponseVerificationSysteme = new ReponseRecuperationMessage(enveloppeSOAP).reponse({
        adaptateurUUID: { genereUUID: () => '' },
        fournisseurFrancais,
      })

      expect(reponseVerificationSysteme.typeJustificatif.id).toBe('abcdef')
    })
  })
})
