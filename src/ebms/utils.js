const { XMLParser } = require('fast-xml-parser')

const { ErreurMessageIllisible } = require('../erreurs')

// `leadingZeros: false` garde `00` — le code de la démarche « vérification
// système » — sous forme de chaîne : sans lui il serait converti en nombre `0`.
const parseXML = (...args) => (
  new XMLParser({
    ignoreAttributes: false,
    removeNSPrefix: true,
    numberParseOptions: { leadingZeros: false },
  }).parse(...args)
)

// L'erreur est typée pour que l'appelant puisse la distinguer d'une défaillance
// interne : sur une requête entrante, elle vaut « requête invalide » et se
// répond par un `EDM:ERR:0003` au lieu de rester sans réponse.
const verifiePresenceSlot = (nomSlot, scopeRecherche) => {
  if (typeof scopeRecherche === 'undefined') {
    throw new ErreurMessageIllisible('Le périmètre de recherche est introuvable.')
  }

  const sectionSlots = scopeRecherche.Slot
  if (typeof sectionSlots === 'undefined') {
    throw new ErreurMessageIllisible('Aucun slot trouvé pour le périmètre de recherche.')
  }

  const slots = [].concat(sectionSlots)
  if (slots.every(s => s['@_name'] !== nomSlot)) {
    throw new ErreurMessageIllisible(`Aucun slot nommé ${nomSlot} trouvé.`)
  }
}

const valeurSlot = (nomSlot, scopeRecherche) => {
  verifiePresenceSlot(nomSlot, scopeRecherche)
  const sectionSlots = scopeRecherche.Slot
  const slots = [].concat(sectionSlots)
  const slot = slots.find(s => s['@_name'] === nomSlot).SlotValue

  switch (slot['@_type']) {
    case 'rim:AnyValueType': return slot
    case 'rim:CollectionValueType': return [].concat(slot.Element)
    default: return slot.Value
  }
}

module.exports = { parseXML, verifiePresenceSlot, valeurSlot }
