const { parseXML } = require('../ebms/utils')

class ReponseDomibus {
  constructor(donnees) {
    this.xml = parseXML(donnees)
  }
}

module.exports = ReponseDomibus
