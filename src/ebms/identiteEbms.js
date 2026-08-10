const { ErreurConfiguration } = require('../erreurs')

// L'identité d'une organisation telle qu'elle voyage dans les propriétés ebMS
// `originalSender` et `finalRecipient` : un identifiant et le schéma qui le
// qualifie.
//
// Les deux sont exigés. Sans eux, l'entête annoncerait `undefined` — chaîne que
// Domibus accepte, puisque la propriété est bien présente et non vide — et le
// pays destinataire ne saurait ni qui demande, ni vers quel fournisseur router.
// Une valeur vide est traitée comme absente : elle ne désigne personne.
const estRenseigne = valeur => typeof valeur === 'string' && valeur.trim() !== ''

const identiteEbms = ({ id, typeId }, quoi) => {
  if (!estRenseigne(id) || !estRenseigne(typeId)) {
    throw new ErreurConfiguration(
      `${quoi} n'a pas d'identité ebMS exploitable : identifiant « ${id} », schéma « ${typeId} ».`,
    )
  }

  return { id, typeId }
}

// Le porteur lui-même peut manquer — un requêteur qu'on n'a pas su lire dans le
// message reçu, un fournisseur que le câblage a oublié.
const exigeIdentite = (porteur, quoi) => {
  if (porteur === undefined || porteur === null) {
    throw new ErreurConfiguration(`${quoi} est absent : impossible d'en tirer une identité ebMS.`)
  }

  return porteur.identiteEbms()
}

module.exports = { estRenseigne, exigeIdentite, identiteEbms }
