const adaptateurEnvironnement = require('../../src/adaptateurs/adaptateurEnvironnement')
const { ErreurConfiguration } = require('../../src/erreurs')

describe('L\'adaptateur d\'environnement', () => {
  let environnementInitial

  beforeEach(() => {
    environnementInitial = { ...process.env }
  })

  afterEach(() => {
    process.env = environnementInitial
  })

  describe('sur l\'identité du fournisseur français', () => {
    it('la lit dans l\'environnement', () => {
      process.env.IDENTIFIANT_FOURNISSEUR_FRANCAIS = '00000000000001'
      process.env.NOM_FOURNISSEUR_FRANCAIS = 'Direction interministérielle du numérique'

      expect(adaptateurEnvironnement.identiteFournisseurFrancais()).toEqual({
        id: '00000000000001',
        nom: 'Direction interministérielle du numérique',
      })
    })

    // Une variable absente ou vide partirait en `undefined` dans chaque réponse
    // émise, sans que Domibus s'en plaigne : mieux vaut ne pas démarrer.
    it.each([
      ['absente', undefined],
      ['vide', ''],
      ['faite d\'espaces', '   '],
    ])('refuse une variable %s', (_, valeur) => {
      process.env.NOM_FOURNISSEUR_FRANCAIS = 'Un fournisseur'
      if (valeur === undefined) delete process.env.IDENTIFIANT_FOURNISSEUR_FRANCAIS
      else process.env.IDENTIFIANT_FOURNISSEUR_FRANCAIS = valeur

      expect(() => adaptateurEnvironnement.identiteFournisseurFrancais())
        .toThrow(ErreurConfiguration)
    })

    it('nomme dans l\'erreur la variable qui manque', () => {
      process.env.IDENTIFIANT_FOURNISSEUR_FRANCAIS = '00000000000001'
      delete process.env.NOM_FOURNISSEUR_FRANCAIS

      expect(() => adaptateurEnvironnement.identiteFournisseurFrancais())
        .toThrow(/NOM_FOURNISSEUR_FRANCAIS/)
    })
  })
  describe('sur l\'URL de la base de données', () => {
    it('la lit dans l\'environnement', () => {
      process.env.URL_BASE_DONNEES = 'postgres://oots_application:secret@postgres:5432/oots_france'

      expect(adaptateurEnvironnement.urlBaseDonnees())
        .toBe('postgres://oots_application:secret@postgres:5432/oots_france')
    })

    // Sans base, aucun échange n'est journalisé, et l'article 17 du règlement
    // (UE) 2022/1463 n'est pas tenu : mieux vaut refuser de démarrer.
    it.each([
      ['absente', undefined],
      ['vide', ''],
      ['faite d\'espaces', '   '],
    ])('refuse une variable %s', (_, valeur) => {
      if (valeur === undefined) delete process.env.URL_BASE_DONNEES
      else process.env.URL_BASE_DONNEES = valeur

      expect(() => adaptateurEnvironnement.urlBaseDonnees()).toThrow(ErreurConfiguration)
    })
  })

  describe('sur l\'adresse d\'OOTS France', () => {
    it('la lit dans l\'environnement', () => {
      process.env.URL_OOTS_FRANCE = 'https://oots.gouv.fr'

      expect(adaptateurEnvironnement.urlOotsFrance()).toEqual('https://oots.gouv.fr')
    })

    // Absente, elle partirait en `returnurl=undefined` chez le correspondant.
    it.each([
      ['absente', undefined],
      ['vide', ''],
      ['faite d\'espaces', '   '],
    ])('refuse une variable %s', (_, valeur) => {
      if (valeur === undefined) delete process.env.URL_OOTS_FRANCE
      else process.env.URL_OOTS_FRANCE = valeur

      expect(() => adaptateurEnvironnement.urlOotsFrance()).toThrow(ErreurConfiguration)
    })
  })
})
