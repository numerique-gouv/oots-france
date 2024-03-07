module.exports = {
  env: {
    browser: true,
    es2021: true,
    jest: true,
  },
  extends: 'airbnb-base',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
  },
  overrides: [{
    files: ['src/erreurs.js'],
    rules: { 'max-classes-per-file': ['off'] },
  }, {
    files: ['test*/**/*.*js'],
    rules: { 'no-new': ['off'] },
  }],
  plugins: ['no-only-tests'],
  rules: {
    'no-param-reassign': ['error', {
      props: true,
      ignorePropertyModificationsFor: ['requete'],
    }],
    'no-only-tests/no-only-tests': 'error',
    'class-methods-use-this': ['error', { enforceForClassFields: false }],
  },
};
