const { XMLParser } = require('fast-xml-parser');

const parseXML = (...args) => (
  new XMLParser({ ignoreAttributes: false, removeNSPrefix: true }).parse(...args)
);

const verifiePresenceSlot = (nomSlot, scopeRecherche) => {
  expect(scopeRecherche).toBeDefined();

  const sectionSlots = scopeRecherche.Slot;
  expect(sectionSlots).toBeDefined();

  const slots = [].concat(sectionSlots);
  expect(slots.some((s) => s['@_name'] === nomSlot)).toBe(true);
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
