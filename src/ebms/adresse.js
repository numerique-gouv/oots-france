const { echappeXML } = require('./echappement')
// L'adresse d'un agent, au sens du `sdg:Address` des TDD. Seul le pays est
// renseigné : c'est le minimum qu'exigent les règles R-EDM-REQ-C073,
// R-EDM-RESP-C047 et R-EDM-ERR-C024 pour les agents classés `ER`, `EP` et
// `ERRP`, et le reste de l'adresse postale n'est pas une donnée dont le dépôt
// dispose. C'est ici, et ici seulement, que s'ajouteront les éléments qu'une
// version ultérieure des TDD rendrait obligatoires.
class Adresse {
  constructor(pays = 'FR') {
    this.pays = pays
  }

  // L'indentation vise le cas courant : les sites d'appel n'imbriquent pas tous
  // à la même profondeur, et l'espacement entre éléments ne porte ici aucun
  // sens.
  enXML() {
    return `<sdg:Address>
          <sdg:AdminUnitLevel1>${echappeXML(this.pays)}</sdg:AdminUnitLevel1>
        </sdg:Address>`
  }
}

module.exports = Adresse
