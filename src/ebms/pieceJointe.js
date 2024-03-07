class PieceJointe {
  constructor(identifiantPieceJointe, contenuPieceJointe) {
    this.idPieceJointe = identifiantPieceJointe;
    this.contenuPieceJointe = contenuPieceJointe;
  }

  enXMLDansEntete() {
    return `
<eb:PartInfo href="${this.idPieceJointe}">
  <eb:PartProperties>
    <eb:Property name="MimeType">application/pdf</eb:Property>
  </eb:PartProperties>
</eb:PartInfo>
    `;
  }

  enXMLDansCorps() {
    return `
<payload payloadId="${this.idPieceJointe}">
  <value>${this.contenuPieceJointe}</value>
</payload>
    `;
  }
}

module.exports = PieceJointe;
