const PieceJointe = require('./pieceJointe');

class PieceJointeVide extends PieceJointe {
  static enXMLDansEntete() {
    return '';
  }
}

module.exports = PieceJointeVide;
