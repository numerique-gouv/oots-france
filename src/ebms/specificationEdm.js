// Version du modèle d'échange (EDM) des TDD que ce dépôt parle. Elle voyage
// dans le slot `SpecificationIdentifier` de chaque message et dans la propriété
// ebMS `SpecificationId` ; les TDD imposent qu'elle corresponde au `ConformsTo`
// que l'Access Service visé publie dans le DSD.
module.exports = {
  IDENTIFIANT_SPECIFICATION_EDM: 'oots-edm:v2.0',
}
