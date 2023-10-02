const { XMLParser } = require('fast-xml-parser');

class ReponseDomibus {
  constructor(donnees) {
    this.parser = new XMLParser({ ignoreAttributes: false });
    this.xml = this.parser.parse(donnees);
  }
}

module.exports = ReponseDomibus;
