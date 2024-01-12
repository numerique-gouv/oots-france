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
};
