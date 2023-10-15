const EcouteurDomibus = require('../src/ecouteurDomibus');

describe("L'écouteur Domibus", () => {
  const adaptateurDomibus = {};

  beforeEach(() => {
    adaptateurDomibus.traiteMessageSuivant = () => {};
  });

  it('peut être démarré et arrêté', (suite) => {
    let nbAppelsTraiteMessageSuivant = 0;
    adaptateurDomibus.traiteMessageSuivant = () => {
      nbAppelsTraiteMessageSuivant += 1;
    };

    const ecouteur = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 20 });
    ecouteur.ecoute();

    setTimeout(() => {
      ecouteur.arreteEcoute();
      try {
        expect(nbAppelsTraiteMessageSuivant).toEqual(2);
        suite();
      } catch (e) {
        suite(e);
      }
    }, 50);
  });

  it("n'est démarré qu'une seule fois à la fois", (suite) => {
    let nbAppelsTraiteMessageSuivant = 0;
    adaptateurDomibus.traiteMessageSuivant = () => {
      nbAppelsTraiteMessageSuivant += 1;
    };

    const ecouteur = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 30 });
    ecouteur.ecoute();
    ecouteur.ecoute();

    setTimeout(() => {
      ecouteur.arreteEcoute();
      try {
        expect(nbAppelsTraiteMessageSuivant).toEqual(2);
        suite();
      } catch (e) {
        suite(e);
      }
    }, 70);
  });

  it("peut être redémarré s'il a été arrêté", (suite) => {
    let nbAppelsTraiteMessageSuivant = 0;
    adaptateurDomibus.traiteMessageSuivant = () => {
      nbAppelsTraiteMessageSuivant += 1;
    };

    const ecouteur = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 20 });
    ecouteur.ecoute();

    setTimeout(() => {
      ecouteur.arreteEcoute();
      ecouteur.ecoute();
    }, 30);

    setTimeout(() => {
      ecouteur.arreteEcoute();
      try {
        expect(nbAppelsTraiteMessageSuivant).toEqual(2);
        suite();
      } catch (e) {
        suite(e);
      }
    }, 60);
  });
});
