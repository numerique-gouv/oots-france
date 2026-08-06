// Les messages sont assemblés par interpolation de gabarits, et une partie des
// valeurs interpolées vient de l'extérieur : l'identifiant et le nom d'un
// requêteur étranger, par exemple, sont lus dans le message qu'il nous a
// envoyé, puis réémis dans notre réponse. fast-xml-parser décode les entités à
// la lecture, si bien qu'un `&lt;` reçu redevient un `<` : le réémettre tel
// quel produirait au mieux un XML mal formé, au pire des éléments dictés par
// l'émetteur.
//
// À appliquer à toute valeur interpolée qui n'est pas un littéral du code —
// texte comme valeur d'attribut, les deux exigeant le même traitement ici.
// L'apostrophe est absente à dessein : elle n'aurait à être échappée que dans
// un attribut délimité par des apostrophes, ce que les gabarits n'emploient
// pas. L'échapper alourdirait chaque nom propre sans rien protéger.
const ENTITES = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
}

const echappeXML = (valeur) => {
  if (typeof valeur === 'undefined' || valeur === null) {
    return ''
  }

  return String(valeur).replace(/[&<>"]/g, caractere => ENTITES[caractere])
}

module.exports = { echappeXML }
