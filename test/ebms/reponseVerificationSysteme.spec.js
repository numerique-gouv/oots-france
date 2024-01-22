const ReponseVerificationSysteme = require('../../src/ebms/reponseVerificationSysteme');
const PointAcces = require('../../src/ebms/pointAcces');

describe('Reponse Verification Systeme', () => {
  const adaptateurUUID = {};
  const horodateur = {};
  const config = { adaptateurUUID, horodateur };
  const donnees = { destinataire: new PointAcces('unTypeIdentifiant', 'unIdentifiant') };

  beforeEach(() => {
    adaptateurUUID.genereUUID = () => '';
    horodateur.maintenant = () => '';
  });

  it('contient une pièce jointe', () => {
    adaptateurUUID.genereUUID = () => '12345678-abcd-abcd-abcd-123456789012';
    const reponse = new ReponseVerificationSysteme(config, donnees);

    expect(reponse.corpsMessageEnXML()).toContain('RepositoryItemRef xlink:href="cid:12345678-abcd-abcd-abcd-123456789012@pdf.oots.fr"');
  });
});
