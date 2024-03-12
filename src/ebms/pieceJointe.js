class PieceJointe {
  constructor(identifiantPieceJointe, contenuPieceJointe) {
    this.identifiant = identifiantPieceJointe;
    this.contenuPieceJointe = contenuPieceJointe;
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
  <value>(${this.contenuPieceJointe})</value>
</payload>
    `;
  }

  contenuEnBase64 = () => '';
}

module.exports = PieceJointe;
