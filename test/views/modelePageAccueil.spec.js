const ModelePageAccueil = require('../../src/views/modelePageAccueil');

describe("La Page d'accueil", () => {
  it("affiche qu'il n'y a pas d'utilisateur courant par défaut", () => {
    const pageAccueil = new ModelePageAccueil(undefined);
    expect(pageAccueil.enHTML()).toContain("Pas d'utilisateur courant");
  });

  it("affiche les prénom et nom de l'utilisatrice courant si elle est connectée", () => {
    const utilisatrice = {
      given_name: 'Sandra',
      family_name: 'Nicouette',
    };

    const pageAccueil = new ModelePageAccueil(utilisatrice);
    expect(pageAccueil.enHTML()).toContain('Utilisateur courant : Sandra Nicouette');
  });
});
