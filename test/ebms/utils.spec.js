const { valeurSlot } = require('../../src/ebms/utils');

describe('`valeurSlot` pour un slot de type `rim:CollectionValueType`', () => {
  it('retourne une liste', () => {
    const xmlParse = {
      Slot: [{
        '@_name': 'Chaines',
        SlotValue: {
          '@_type': 'rim:CollectionValueType',
          Element: [
            { Chaine: 'Un truc' },
            { Chaine: 'Un autre truc' },
          ],
        },
      }],
    };

    const chaines = valeurSlot('Chaines', xmlParse).map((v) => v.Chaine);
    expect(chaines).toEqual(['Un truc', 'Un autre truc']);
  });

  it("retourne une liste, même s'il n'y a qu'un seul élément dans la collection", () => {
    const xmlParse = {
      Slot: [{
        '@_name': 'Chaines',
        SlotValue: {
          '@_type': 'rim:CollectionValueType',
          Element: { Chaine: 'Un truc' },
        },
      }],
    };

    const chaines = valeurSlot('Chaines', xmlParse).map((v) => v.Chaine);
    expect(chaines).toEqual(['Un truc']);
  });
});
