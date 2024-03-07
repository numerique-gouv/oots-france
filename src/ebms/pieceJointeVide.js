const PieceJointe = require('./pieceJointe');

class PieceJointeVide extends PieceJointe {
  enXMLDansEntete = () => '';

  enXMLDansCorps = () => '';
}

module.exports = PieceJointeVide;
