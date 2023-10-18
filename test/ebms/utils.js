const verifiePresenceSlot = (nomSlot, scopeRecherche) => {
  expect(scopeRecherche).toBeDefined();

  const sectionSlots = scopeRecherche['rim:Slot'];
  expect(sectionSlots).toBeDefined();

  const slots = [].concat(sectionSlots);
  expect(slots.some((s) => s['@_name'] === nomSlot)).toBe(true);
};

const valeurSlot = (nomSlot, scopeRecherche) => {
  verifiePresenceSlot(nomSlot, scopeRecherche);
  const sectionSlots = scopeRecherche['rim:Slot'];
  const slots = [].concat(sectionSlots);
  return slots.find((s) => s['@_name'] === nomSlot)['rim:SlotValue']['rim:Value'];
};

module.exports = { verifiePresenceSlot, valeurSlot };
