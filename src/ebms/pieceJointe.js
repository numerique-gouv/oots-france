class PieceJointe {
  constructor(identifiantPieceJointe, contenu) {
    this.identifiant = identifiantPieceJointe;
    this.contenu = contenu;
  }

  enXMLDansEntete() {
    return `
<eb:PartInfo href="${this.identifiant}">
  <eb:PartProperties>
    <eb:Property name="MimeType">application/pdf</eb:Property>
  </eb:PartProperties>
</eb:PartInfo>
    `;
  }

  enXMLDansCorps() {
    return `
<payload payloadId="${this.identifiant}">
  <value>(${this.contenu})</value>
</payload>
    `;
  }
}

module.exports = PieceJointe;
