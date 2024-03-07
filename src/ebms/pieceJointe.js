class PieceJointe {
  constructor(identifiantPieceJointe) {
    this.idPieceJointe = identifiantPieceJointe;
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
}

module.exports = PieceJointe;
