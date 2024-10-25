const axios = require('axios');

const envoie = (pieceJustificative, urlBaseRequeteur) => axios.post(
  `${urlBaseRequeteur}/oots/document`,
  { document: pieceJustificative },
  { header: { 'Content-Type': 'application/pdf; charset=utf-8' } },
);

module.exports = { envoie };
