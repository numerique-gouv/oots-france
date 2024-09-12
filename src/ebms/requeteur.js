class Requeteur {
  constructor(donnees = {}) {
    this.id = donnees.id;
    this.nom = donnees.nom;
    this.url = donnees.url;
  }
}

module.exports = Requeteur;
