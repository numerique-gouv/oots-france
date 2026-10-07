require 'rails_helper'

RSpec.describe Administrator do
  describe '.appoint' do
    it 'keeps the address lowercase and without surrounding blanks' do
      described_class.appoint('  Prenom.Nom@Numerique.gouv.fr ')

      expect(described_class.pluck(:email)).to eq(['prenom.nom@numerique.gouv.fr'])
    end

    it 'names an address once however many times it is appointed' do
      2.times { described_class.appoint('Prenom.Nom@Numerique.gouv.fr') }

      expect(described_class.count).to eq(1)
    end
  end

  describe '.dismiss' do
    it 'removes the address, whatever its case' do
      described_class.appoint('prenom.nom@numerique.gouv.fr')

      described_class.dismiss('PRENOM.NOM@numerique.gouv.fr')

      expect(described_class.count).to eq(0)
    end
  end

  describe '.appointed?' do
    before { described_class.appoint('prenom.nom@numerique.gouv.fr') }

    it 'recognises the address ProConnect returns, whatever its case' do
      expect(described_class.appointed?('Prenom.Nom@numerique.gouv.fr')).to be(true)
    end

    it 'refuses an address nobody appointed' do
      expect(described_class.appointed?('autre@numerique.gouv.fr')).to be(false)
    end

    it 'refuses a missing address' do
      expect(described_class.appointed?(nil)).to be(false)
    end
  end
end
