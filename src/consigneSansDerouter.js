// Écrit au journal sans jamais dérouter l'appelant.
//
// Les écritures du chapitre 4.8 suivent presque toujours une action
// irréversible — un message ebMS déjà parti, une réponse HTTP déjà envoyée, un
// message que la passerelle a déjà consommé. Laisser leur échec remonter
// reviendrait à défaire ce qui a déjà eu lieu : renvoyer un 500 au requêteur
// pour un échange pourtant transmis, ou renoncer à répondre à une autorité qui
// attend. L'incident est donc consigné à la sortie d'erreur standard, avec de
// quoi le retrouver, et la conversation se poursuit.
//
// **Tout ce qu'on confie ici est paresseux**, l'écriture comme le détail :
//
// - `ecriture` est un thunk, et non une promesse déjà créée. Une erreur levée
//   en *assemblant* l'événement — un slot RegRep absent d'un message inattendu
//   — échapperait sinon au rattrapage, l'appel n'ayant jamais rendu de promesse
//   à laquelle l'accrocher ;
// - `detail` en est un aussi, pour la même raison exactement. Il nomme la
//   conversation et le message, donc il relit ces identifiants — les mêmes
//   accesseurs, susceptibles de lever pour les mêmes causes. Évalué à l'appel,
//   il ferait échouer la journalisation avant même qu'elle commence, et cette
//   fois hors de tout filet.
//
// Un `detail` qui lève malgré tout ne relance pas : la trace vaut mieux
// approximative que perdue.
const consigneSansDerouter = (ecriture, libelle, detail) => Promise.resolve()
  .then(ecriture)
  .catch((echec) => {
    let precision
    try {
      precision = detail()
    }
    catch {
      precision = 'contexte illisible'
    }

    // L'erreur entière, et non son seul message : la pile dit où, et une erreur
    // `pg` porte dans `code` et `detail` la raison du refus — contrainte
    // violée, connexion perdue — que `message` résume mal.
    console.error(`${libelle} sans trace au journal (${precision}) :`, echec)
  })

module.exports = consigneSansDerouter
