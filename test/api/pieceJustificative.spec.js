const pieceJustificative = require('../../src/api/pieceJustificative')
const depotJournalFactice = require('../constructeurs/depotJournalFactice')
const PointAcces = require('../../src/ebms/pointAcces')
const Fournisseur = require('../../src/ebms/fournisseur')
const Requeteur = require('../../src/ebms/requeteur')
const TypeJustificatif = require('../../src/ebms/typeJustificatif')

const {
  ErreurAbsenceReponseDestinataire,
  ErreurConfiguration,
  ErreurDestinataireInexistant,
  ErreurRequeteurInexistant,
  ErreurReponseRequete,
} = require('../../src/erreurs')

describe('Le requêteur de pièce justificative', () => {
  const adaptateurChiffrement = {}
  const adaptateurDomibus = {}
  const adaptateurEnvironnement = {}
  const adaptateurUUID = {}
  const depotJournal = {}
  const depotPointsAcces = {}
  const depotRequeteurs = {}
  const depotServicesCommuns = {}
  const transmetteurPiecesJustificatives = {}

  const config = {
    adaptateurChiffrement,
    adaptateurDomibus,
    adaptateurEnvironnement,
    adaptateurUUID,
    depotJournal,
    depotPointsAcces,
    depotRequeteurs,
    depotServicesCommuns,
    transmetteurPiecesJustificatives,
  }
  const requete = {}
  const reponse = {}

  beforeEach(() => {
    adaptateurChiffrement.dechiffreJWE = () => Promise.resolve({})
    adaptateurChiffrement.empreinteSha256 = () => 'uneEmpreinte'
    Object.assign(depotJournal, depotJournalFactice())
    adaptateurDomibus.envoieMessageRequete = () => Promise.resolve({ idMessage: '', idRequete: '' })
    adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.resolve()
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve()
    adaptateurEnvironnement.urlOotsFrance = () => 'http://localhost:1234'
    adaptateurUUID.genereUUID = () => ''
    depotPointsAcces.trouvePointAcces = () => Promise.resolve({})
    depotRequeteurs.trouveRequeteur = () => Promise.resolve(
      new Requeteur({ adaptateurChiffrement }),
    )
    depotServicesCommuns.trouveFournisseurs = () => Promise.resolve([new Fournisseur()])
    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = () => Promise.resolve(
      [new TypeJustificatif()],
    )
    transmetteurPiecesJustificatives.envoie = () => Promise.resolve()

    requete.query = {}
    reponse.headersSent = false
    reponse.json = () => Promise.resolve()
    reponse.redirect = () => Promise.resolve()
    reponse.send = () => Promise.resolve()
    reponse.set = () => Promise.resolve()
    reponse.status = () => reponse
  })

  it('envoie un message AS4 au bon destinataire', () => {
    expect.assertions(2)
    depotPointsAcces.trouvePointAcces = () => Promise.resolve(new PointAcces('unIdentifiant', 'unType'))

    adaptateurDomibus.envoieMessageRequete = ({ destinataire }) => {
      expect(destinataire.id).toEqual('unIdentifiant')
      expect(destinataire.typeId).toEqual('unType')
      return Promise.resolve({ idMessage: '', idRequete: '' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('transmet le code démarche dans la requête', () => {
    expect.assertions(1)
    requete.query.codeDemarche = 'UN_CODE'

    adaptateurDomibus.envoieMessageRequete = ({ codeDemarche }) => {
      expect(codeDemarche).toEqual('UN_CODE')
      return Promise.resolve({ idMessage: '', idRequete: '' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('interroge dépôt services communs pour récupérer infos relatives au code démarche', () => {
    expect.assertions(1)
    requete.query.codeDemarche = '00'

    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = (code) => {
      expect(code).toBe('00')
      return Promise.resolve([new TypeJustificatif()])
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('transmet l\'identifiant de type de pièce justificative demandée', () => {
    expect.assertions(1)
    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = () => Promise.resolve([{ id: 'unIdentifiant' }])

    adaptateurDomibus.envoieMessageRequete = ({ typeJustificatif }) => {
      expect(typeJustificatif.id).toEqual('unIdentifiant')
      return Promise.resolve({ idMessage: '', idRequete: '' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('interroge dépôt services communs pour récupérer fournisseurs relatifs au justificatif et au code pays', () => {
    expect.assertions(2)
    requete.query.codePays = 'FR'
    depotServicesCommuns.trouveTypesJustificatifsPourDemarche = () => Promise.resolve([{ id: 'unIdentifiant' }])

    depotServicesCommuns.trouveFournisseurs = (idTypeJustificatif, codePays) => {
      expect(idTypeJustificatif).toBe('unIdentifiant')
      expect(codePays).toBe('FR')
      return Promise.resolve([new Fournisseur()])
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('transmet fournisseur à requête', () => {
    expect.assertions(1)

    depotServicesCommuns.trouveFournisseurs = () => (
      Promise.resolve([new Fournisseur({ descriptions: { FR: 'Un fournisseur' } })])
    )

    adaptateurDomibus.envoieMessageRequete = ({ fournisseur }) => {
      expect(fournisseur.descriptions.FR).toBe('Un fournisseur')
      return Promise.resolve({ idMessage: '', idRequete: '' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('interroge le dépôt de requêteurs', () => {
    expect.assertions(1)
    requete.query.idRequeteur = '123456'

    depotRequeteurs.trouveRequeteur = (id) => {
      expect(id).toBe('123456')
      return Promise.resolve(new Requeteur({ adaptateurChiffrement }))
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('transmet requêteur à requête', () => {
    expect.assertions(1)
    depotRequeteurs.trouveRequeteur = () => Promise.resolve(new Requeteur({ adaptateurChiffrement }, { nom: 'Un requêteur' }))

    adaptateurDomibus.envoieMessageRequete = ({ requeteur }) => {
      expect(requeteur.nom).toBe('Un requêteur')
      return Promise.resolve({ idMessage: '', idRequete: '' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('déchiffre les infos bénéficiaire reçues', () => {
    expect.assertions(1)
    adaptateurChiffrement.dechiffreJWE = (jwe) => {
      expect(jwe).toBe('abcdef')
      return Promise.resolve({})
    }
    depotRequeteurs.trouveRequeteur = () => Promise.resolve(
      new Requeteur({ adaptateurChiffrement }),
    )

    requete.query.beneficiaire = 'abcdef'
    return pieceJustificative(config, requete, reponse)
  })

  it('transmet la personne physique bénéficiaire à la requête', () => {
    adaptateurChiffrement.dechiffreJWE = () => Promise.resolve({ nomUsage: 'Dupond' })
    depotRequeteurs.trouveRequeteur = () => Promise.resolve(
      new Requeteur({ adaptateurChiffrement }),
    )

    adaptateurDomibus.envoieMessageRequete = ({ beneficiaire }) => {
      expect(beneficiaire.nom).toBe('Dupond')
      return Promise.resolve({ idMessage: '', idRequete: '' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('génère une erreur 422 lorsque le requêteur n\'existe pas', () => {
    expect.assertions(2)
    requete.query.idRequeteur = 'requeteurInexistant'
    depotRequeteurs.trouveRequeteur = () => Promise.reject(new ErreurRequeteurInexistant('Oups'))

    reponse.status = (codeStatus) => {
      expect(codeStatus).toEqual(422)
      return reponse
    }
    reponse.json = (contenu) => {
      expect(contenu).toEqual({ erreur: 'Oups' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('utilise un identifiant de conversation', () => {
    expect.assertions(2)
    adaptateurUUID.genereUUID = () => '11111111-1111-1111-1111-111111111111'

    adaptateurDomibus.envoieMessageRequete = ({ idConversation }) => {
      expect(idConversation).toEqual('11111111-1111-1111-1111-111111111111')
      return Promise.resolve({ idMessage: '', idRequete: '' })
    }

    adaptateurDomibus.urlRedirectionDepuisReponse = (idConversation) => {
      expect(idConversation).toEqual('11111111-1111-1111-1111-111111111111')
      return Promise.resolve()
    }

    return pieceJustificative(config, requete, reponse)
  })

  describe('quand une prévisualisation est requise', () => {
    it('ajoute l\'adresse de retour et sa méthode à l\'URL de prévisualisation', () => {
      expect.assertions(1)
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve('https://example.com/apercu')

      reponse.redirect = (urlRedirection) => {
        expect(urlRedirection).toEqual(
          'https://example.com/apercu?returnurl=http%3A%2F%2Flocalhost%3A1234&returnmethod=GET',
        )
        return Promise.resolve()
      }

      return pieceJustificative(config, requete, reponse)
    })

    it('préserve les paramètres que l\'espace de prévisualisation porte déjà', () => {
      expect.assertions(3)
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve('https://example.com/apercu?jeton=abc')

      reponse.redirect = (urlRedirection) => {
        const parametres = new URL(urlRedirection).searchParams
        expect(parametres.get('jeton')).toEqual('abc')
        expect(parametres.get('returnurl')).toEqual('http://localhost:1234')
        expect(parametres.get('returnmethod')).toEqual('GET')
        return Promise.resolve()
      }

      return pieceJustificative(config, requete, reponse)
    })

    // Les TDD interdisent à l'adresse de prévisualisation de porter ces deux
    // noms : si elle le fait quand même, c'est la valeur du portail qui vaut.
    it('écrase une adresse de retour que l\'espace de prévisualisation aurait posée', () => {
      expect.assertions(2)
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve(
        'https://example.com/apercu?returnurl=https%3A%2F%2Fusurpateur.example&returnmethod=POST',
      )

      reponse.redirect = (urlRedirection) => {
        const parametres = new URL(urlRedirection).searchParams
        expect(parametres.getAll('returnurl')).toEqual(['http://localhost:1234'])
        expect(parametres.getAll('returnmethod')).toEqual(['GET'])
        return Promise.resolve()
      }

      return pieceJustificative(config, requete, reponse)
    })

    // La configuration est lue avant que la course ne démarre : sans cela,
    // l'échec resterait caché derrière la branche qui attend Domibus.
    it('échoue sans attendre Domibus quand l\'adresse de retour n\'est pas configurée', () => {
      expect.assertions(1)
      adaptateurEnvironnement.urlOotsFrance = () => {
        throw new ErreurConfiguration('URL_OOTS_FRANCE est obligatoire')
      }
      adaptateurDomibus.reponseAvecPieceJustificative = () => new Promise(() => {})

      reponse.status = (codeStatus) => {
        expect(codeStatus).toEqual(500)
        return reponse
      }

      return pieceJustificative(config, requete, reponse)
    })

    it('rend une erreur métier quand l\'adresse de prévisualisation reçue est illisible', () => {
      expect.assertions(2)
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve('pas une URL')
      adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.reject(
        new ErreurAbsenceReponseDestinataire('aucun justificatif reçu'),
      )

      reponse.status = (codeStatus) => {
        expect(codeStatus).toEqual(502)
        return reponse
      }
      reponse.json = ({ erreur }) => {
        expect(erreur).toContain('Adresse de prévisualisation reçue illisible')
      }

      return pieceJustificative(config, requete, reponse)
    })
  })

  it('accepte de recevoir directement la pièce justificative', () => {
    let pieceJustificativeRecue = false
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL de redirection reçue'))
    adaptateurDomibus.reponseAvecPieceJustificative = () => {
      pieceJustificativeRecue = true
      return Promise.resolve({ idMessage: '', idRequete: '' })
    }

    return pieceJustificative(config, requete, reponse)
      .then(() => expect(pieceJustificativeRecue).toBe(true))
  })

  describe('sur réception réponse avec pièce justificative', () => {
    const reponseAvecPJ = {}

    beforeEach(() => {
      reponseAvecPJ.idRequeteur = () => ''
      reponseAvecPJ.pieceJustificative = () => Buffer.from('')

      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject()
      adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.resolve(reponseAvecPJ)
    })

    it('renvoie la pièce justificative au fournisseur de service', () => {
      expect.assertions(2)

      reponseAvecPJ.pieceJustificative = () => Buffer.from('Des données')
      depotRequeteurs.trouveRequeteur = () => Promise.resolve(
        new Requeteur({ adaptateurChiffrement }, { url: 'http://example.com' }),
      )

      transmetteurPiecesJustificatives.envoie = (pj, urlBase) => {
        expect(pj.toString()).toBe('Des données')
        expect(urlBase).toBe('http://example.com')
        return Promise.resolve()
      }

      return pieceJustificative(config, requete, reponse)
    })

    it('redirige l\'utilisateur vers une URL de callback chez le fournisseur de service', () => {
      expect.assertions(1)

      depotRequeteurs.trouveRequeteur = () => Promise.resolve(
        new Requeteur({ adaptateurChiffrement }, { url: 'http://example.com' }),
      )

      reponse.redirect = (urlRedirection) => {
        expect(urlRedirection).toBe('http://example.com/oots/callback')
        return Promise.resolve()
      }

      return pieceJustificative(config, requete, reponse)
    })
  })

  it('génère une erreur HTTP 502 (Bad Gateway) sur réception d\'une réponse en erreur', () => {
    expect.assertions(2)
    adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurReponseRequete('object not found'))
    adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucun justificatif reçu'))

    reponse.status = (codeStatus) => {
      expect(codeStatus).toEqual(502)
      return reponse
    }

    reponse.json = (contenu) => {
      expect(contenu).toEqual({ erreur: 'object not found ; aucun justificatif reçu' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  it('génère une erreur 422 lorsque le destinataire n\'existe pas', () => {
    expect.assertions(2)
    requete.query.destinataire = 'DESTINATAIRE_INEXISTANT'
    depotPointsAcces.trouvePointAcces = () => Promise.reject(new ErreurDestinataireInexistant('Oups'))

    reponse.status = (codeStatus) => {
      expect(codeStatus).toEqual(422)
      return reponse
    }
    reponse.json = (contenu) => {
      expect(contenu).toEqual({ erreur: 'Oups' })
    }

    return pieceJustificative(config, requete, reponse)
  })

  describe('sur le journal des échanges', () => {
    it('consigne la requête émise, avec son contexte métier et l\'identifiant du message', () => {
      adaptateurUUID.genereUUID = () => 'uneConversation'
      adaptateurDomibus.envoieMessageRequete = () => Promise.resolve({ idMessage: 'unMessage@oots.eu', idRequete: 'urn:uuid:uneRequete' })
      requete.query.codeDemarche = 'T1'
      requete.query.idRequeteur = '12345678901234'

      return pieceJustificative(config, requete, reponse)
        .then(() => {
          const [evenement] = depotJournal.evenementsDeType('requete_emise')

          expect(evenement.idConversation).toBe('uneConversation')
          expect(evenement.idMessage).toBe('unMessage@oots.eu')
          expect(evenement.idRequeteur).toBe('12345678901234')
          expect(evenement.codeDemarche).toBe('T1')
          expect(evenement.actionEbms).toBe('ExecuteQueryRequest')
        })
    })

    it('consigne la remise de la pièce au requêteur, par son empreinte', () => {
      adaptateurUUID.genereUUID = () => 'uneConversation'
      adaptateurChiffrement.empreinteSha256 = () => 'empreinteDuJustificatif'
      // Sans quoi la redirection de prévisualisation, résolue par défaut,
      // gagne la course et la pièce n'est jamais remise.
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL reçue'))
      adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.resolve({
        idRequeteur: () => '12345678901234',
        pieceJustificative: () => Buffer.from('Des données'),
      })
      depotRequeteurs.trouveRequeteur = () => Promise.resolve(
        new Requeteur({ adaptateurChiffrement }, { url: 'http://example.com' }),
      )

      return pieceJustificative(config, requete, reponse)
        .then(() => {
          const [evenement] = depotJournal.evenementsDeType('piece_transmise')

          expect(evenement.idConversation).toBe('uneConversation')
          expect(evenement.idRequeteur).toBe('12345678901234')
          expect(evenement.empreinteJustificatif).toBe('empreinteDuJustificatif')
          expect(evenement.typeMime).toBe('application/pdf')
        })
    })

    // Ce refus ne produit aucun message ebMS : sans cette trace, l'erreur que
    // l'article 17 demande de journaliser n'existerait nulle part.
    it('consigne un refus prononcé avant tout envoi', () => {
      depotPointsAcces.trouvePointAcces = () => Promise.reject(new ErreurDestinataireInexistant('Oups'))
      requete.query.idRequeteur = '12345678901234'

      return pieceJustificative(config, requete, reponse)
        .then(() => {
          const [evenement] = depotJournal.evenementsDeType('requete_refusee')

          expect(evenement.codeErreur).toBe('ErreurDestinataireInexistant')
          expect(evenement.idRequeteur).toBe('12345678901234')
        })
    })

    // La requête est partie : la signaler en erreur ferait retenter le
    // requêteur, donc instruire deux fois le même échange chez le fournisseur.
    it('n\'interrompt pas la conversation quand la requête émise ne peut être consignée', () => {
      adaptateurDomibus.envoieMessageRequete = () => Promise.resolve({ idMessage: 'unMessage@oots.eu', idRequete: 'urn:uuid:uneRequete' })
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.resolve('https://apercu.example.com')
      depotJournal.consigneRequeteEmise = () => Promise.reject(new Error('base indisponible'))

      let statut
      reponse.status = (code) => {
        statut = code
        return reponse
      }

      return pieceJustificative(config, requete, reponse)
        .then(() => expect(statut).toBeUndefined())
    })

    // Écrire par-dessus une réponse déjà partie lèverait `ERR_HTTP_HEADERS_SENT`
    // dans un `.then` que la route ne rend pas à Express : la rejection
    // orpheline emporterait le processus.
    it('ne répond pas une seconde fois quand l\'échec survient après la redirection', () => {
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL reçue'))
      adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.resolve({
        idRequeteur: () => '12345678901234',
        pieceJustificative: () => Buffer.from('Des données'),
      })
      depotRequeteurs.trouveRequeteur = () => Promise.resolve(
        new Requeteur({ adaptateurChiffrement }, { url: 'http://example.com' }),
      )
      transmetteurPiecesJustificatives.envoie = () => Promise.reject(new Error('requêteur injoignable'))

      let statut
      reponse.redirect = () => {
        reponse.headersSent = true
        return Promise.resolve()
      }
      reponse.status = (code) => {
        statut = code
        return reponse
      }

      return pieceJustificative(config, requete, reponse)
        .then(() => expect(statut).toBeUndefined())
    })

    // Le journal raconte déjà l'échange : `requete_emise` sans réponse dit
    // l'expiration. Le redire en refus laisserait croire qu'on n'a rien envoyé.
    it('ne consigne pas de refus quand la requête est partie et reste sans réponse', () => {
      adaptateurDomibus.urlRedirectionDepuisReponse = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune URL reçue'))
      adaptateurDomibus.reponseAvecPieceJustificative = () => Promise.reject(new ErreurAbsenceReponseDestinataire('aucune pièce reçue'))

      return pieceJustificative(config, requete, reponse)
        .then(() => {
          expect(depotJournal.evenementsDeType('requete_emise')).toHaveLength(1)
          expect(depotJournal.evenementsDeType('requete_refusee')).toHaveLength(0)
        })
    })
  })
})
