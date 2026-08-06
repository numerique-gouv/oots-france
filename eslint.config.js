const js = require('@eslint/js')
const stylistic = require('@stylistic/eslint-plugin')
const importX = require('eslint-plugin-import-x')
const greffonNoOnlyTests = require('eslint-plugin-no-only-tests')
const globals = require('globals')

// `eslint-config-airbnb-base`, sous lequel tout le code avait été écrit, est
// resté à ESLint 8 : jamais porté vers la configuration à plat, et figé sur une
// dépendance de pair que plus rien ne satisfait. Les trois bases génériques qui
// le remplacent sont prises telles quelles, sans réglage : c'est le code qui
// s'aligne sur elles, et non l'inverse.
module.exports = [
  { ignores: ['.worktrees/', 'node_modules/'] },

  js.configs.recommended,
  importX.flatConfigs.recommended,
  stylistic.configs.recommended,

  {
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'commonjs',
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
    plugins: { 'no-only-tests': greffonNoOnlyTests },
    rules: {
      // Les deux seules règles ajoutées, et aucune ne relève du style.
      //
      // `no-only-tests` est une exigence du projet : un `.only` commité
      // masquerait toute la suite sans faire échouer l'intégration continue.
      'no-only-tests/no-only-tests': 'error',
      // `import-x` ne vise par défaut que la syntaxe des modules ES : sans
      // `commonjs`, il ne verrait aucun des `require` du projet, et la base
      // recommandée ci-dessus ne signalerait jamais rien.
      'import-x/no-unresolved': ['error', { commonjs: true }],
    },
  },

  {
    files: ['test*/**/*.?(c|m)js'],
    languageOptions: { globals: globals.jest },
  },
]
