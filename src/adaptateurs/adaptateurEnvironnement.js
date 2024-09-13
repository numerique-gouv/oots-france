const avecRequetePieceJustificative = () => process.env.AVEC_REQUETE_PIECE_JUSTIFICATIVE === 'true';

const donneesDepotServicesCommunsLocal = () => (
  JSON.parse(process.env.DONNEES_DEPOT_SERVICES_COMMUNS_LOCAL)
);

const donneesRequeteurs = () => JSON.parse(process.env.DONNEES_REQUETEURS);

module.exports = {
  avecRequetePieceJustificative,
  donneesDepotServicesCommunsLocal,
  donneesRequeteurs,
};
