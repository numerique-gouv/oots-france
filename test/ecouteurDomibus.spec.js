const EcouteurDomibus = require('../src/ecouteurDomibus');

describe("L'écouteur Domibus", () => {
  jest.useFakeTimers();
  const adaptateurDomibus = {};

  beforeEach(() => {
    adaptateurDomibus.traiteMessageSuivant = () => {
    };
  });

  it('peut être démarré et arrêté', () => {
    adaptateurDomibus.traiteMessageSuivant = jest.fn();

    const ecouteur = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 20 });
    ecouteur.ecoute();

    expect(adaptateurDomibus.traiteMessageSuivant).not.toHaveBeenCalled();

    jest.advanceTimersByTime(50);

    expect(adaptateurDomibus.traiteMessageSuivant).toHaveBeenCalled();
    expect(adaptateurDomibus.traiteMessageSuivant).toHaveBeenCalledTimes(2);

    ecouteur.arreteEcoute();

    jest.advanceTimersByTime(50);

    expect(adaptateurDomibus.traiteMessageSuivant).toHaveBeenCalledTimes(2);
  });

  it("n'est démarré qu'une seule fois à la fois", () => {
    adaptateurDomibus.traiteMessageSuivant = jest.fn();

    const ecouteur = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 20 });
    ecouteur.ecoute();
    ecouteur.ecoute();

    jest.advanceTimersByTime(30);

    expect(adaptateurDomibus.traiteMessageSuivant).toHaveBeenCalledTimes(1);
  });

  it("peut être redémarré s'il a été arrêté", () => {
    adaptateurDomibus.traiteMessageSuivant = jest.fn();

    const ecouteur = new EcouteurDomibus({ adaptateurDomibus, intervalleEcoute: 20 });
    ecouteur.ecoute();
    jest.advanceTimersByTime(30);
    ecouteur.arreteEcoute();
    ecouteur.ecoute();

    jest.advanceTimersByTime(30);

    expect(adaptateurDomibus.traiteMessageSuivant).toHaveBeenCalledTimes(2);
  });
});
