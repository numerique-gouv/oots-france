// Le schéma d'identifiant des organisations françaises : le code EAS `0009`,
// qui désigne le SIRET. Un identifiant d'organisation ne veut rien dire seul —
// il faut nommer le répertoire d'où il sort — et les TDD recommandent un code
// de la liste EAS plutôt que le repli `unregistered`. Voir « Identifier une
// organisation » dans docs/oots_context.md.
//
// Les organisations étrangères portent, elles, le schéma lu dans leur message.
module.exports = {
  SCHEME_ID_FRANCAIS: 'urn:cef.eu:names:identifier:EAS:0009',
  // Le repli, pour les identités françaises qui n'ont pas encore de SIRET.
  SCHEME_ID_REPLI_FRANCAIS: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR',
}
