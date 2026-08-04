// Configuration Jest du test e2e (cf. docs/test_e2e.md).
// Volontairement séparée de celle de `package.json` : ce scénario exige la pile
// complète (web + domibus + mysql), que l'intégration continue n'a pas, et
// dépasse largement le délai d'une seconde imposé aux tests unitaires.

module.exports = {
  testMatch: ['**/test-e2e/**/*.spec.js'],
  // Le motif descend dans tout l'arbre : sans cette exclusion, les worktrees
  // de .worktrees/ — le mode de travail parallèle décrit dans CLAUDE.md —
  // seraient collectés eux aussi, et le scénario rejoué autant de fois contre
  // la même passerelle, avec la version d'une autre branche.
  testPathIgnorePatterns: ['/node_modules/', '/.worktrees/'],
  testTimeout: 90000,
}
