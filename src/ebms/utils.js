const { XMLParser } = require('fast-xml-parser');

const parseXML = (...args) => (
  new XMLParser({ ignoreAttributes: false, removeNSPrefix: true }).parse(...args)
);

const verifiePresenceSlot = (nomSlot, scopeRecherche) => {
  if (typeof scopeRecherche === 'undefined') { throw new Error('Le périmètre de recherche est introuvable.'); }

  const sectionSlots = scopeRecherche.Slot;
  if (typeof sectionSlots === 'undefined') { throw new Error('Aucun slot trouvé pour le périmètre de recherche.'); }

  const slots = [].concat(sectionSlots);
  if (slots.every((s) => s['@_name'] !== nomSlot)) { throw new Error(`Aucun slot nommé ${nomSlot} trouvé.`); }
};

const valeurSlot = (nomSlot, scopeRecherche) => {
  verifiePresenceSlot(nomSlot, scopeRecherche);
  const sectionSlots = scopeRecherche.Slot;
  const slots = [].concat(sectionSlots);
  const slot = slots.find((s) => s['@_name'] === nomSlot).SlotValue;

  switch (slot['@_type']) {
    case 'rim:AnyValueType': return slot;
    case 'rim:CollectionValueType': return slot.Element;
    default: return slot.Value;
  }
};

module.exports = { parseXML, verifiePresenceSlot, valeurSlot };
