const { XMLParser } = require('fast-xml-parser');

class ReponseDomibus {
  constructor(donnees) {
    this.parser = new XMLParser({
      ignoreAttributes: false,
      removeNSPrefix: true,
    });
    this.xml = this.parser.parse(donnees);
  }
}

module.exports = ReponseDomibus;
