// Écrit au journal sans jamais dérouter l'appelant.
//
// Les écritures du chapitre 4.8 suivent presque toujours une action
// irréversible — un message ebMS déjà parti, une réponse HTTP déjà envoyée, un
// message que la passerelle a déjà consommé. Laisser leur échec remonter
// reviendrait à défaire ce qui a déjà eu lieu : renvoyer un 500 au requêteur
// pour un échange pourtant transmis, ou renoncer à répondre à une autorité qui
// attend. L'incident est donc consigné à la sortie standard, avec de quoi le
// retrouver, et la conversation se poursuit.
//
// `Promise.resolve().then(ecriture)` plutôt que `ecriture().catch(…)` : une
// erreur levée en **assemblant** ce qu'on passe au journal — un slot RegRep
// absent d'un message inattendu — échapperait sinon au rattrapage, l'appel
// n'ayant jamais rendu de promesse à laquelle l'accrocher.
const consigneSansDerouter = (ecriture, contexte) => Promise.resolve()
  .then(ecriture)
  .catch(echec => console.error(`${contexte} : ${echec.message}`))

module.exports = consigneSansDerouter
