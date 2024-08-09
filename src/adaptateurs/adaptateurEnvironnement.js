const avecRequetePieceJustificative = () => process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE === 'true';

const donneesDepotServicesCommunsLocal = () => (
  JSON.parse(process.env.DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL)
);

module.exports = {
  avecRequetePieceJustificative,
  donneesDepotServicesCommunsLocal,
};
