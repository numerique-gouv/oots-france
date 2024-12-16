const crypto = require('crypto');

const cleHachage = (chaine) => crypto.createHash('md5').update(chaine).digest('hex');

module.exports = {
  cleHachage,
};
