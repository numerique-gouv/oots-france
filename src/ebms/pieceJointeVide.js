const PieceJointe = require('./pieceJointe');

class PieceJointeVide extends PieceJointe {
  enXML() {
    return '';
  }
}

module.exports = PieceJointeVide;
