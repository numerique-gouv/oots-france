require 'rails_helper'

RSpec.describe Guest do
  describe '.invite' do
    it 'keeps the address lowercase and without surrounding blanks' do
      described_class.invite('  Partenaire@Exemple.fr ')

      expect(described_class.pluck(:email)).to eq(['partenaire@exemple.fr'])
    end

    it 'invites an address once however many times it is invited' do
      described_class.invite('Partenaire@Exemple.fr')
      described_class.invite('partenaire@exemple.fr')

      expect(described_class.count).to eq(1)
    end

    it 'refuses a blank address' do
      expect { described_class.invite('   ') }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '.withdraw' do
    it 'removes the address, whatever its case' do
      described_class.invite('partenaire@exemple.fr')

      described_class.withdraw('PARTENAIRE@exemple.fr')

      expect(described_class.count).to eq(0)
    end
  end

  describe '.invited?' do
    before { described_class.invite('partenaire@exemple.fr') }

    it 'recognises the address ProConnect returns, whatever its case' do
      expect(described_class.invited?('Partenaire@Exemple.fr')).to be(true)
    end

    it 'refuses an address nobody invited' do
      expect(described_class.invited?('autre@exemple.fr')).to be(false)
    end

    it 'refuses a missing address' do
      expect(described_class.invited?(nil)).to be(false)
    end
  end
end
