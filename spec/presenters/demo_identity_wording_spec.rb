require 'rails_helper'

RSpec.describe DemoIdentityWording do
  # The code FranceConnect+ publishes is not a word, and the screen must say one.
  describe '#gender' do
    it 'says each of the three the portal publishes' do
      expect(described_class.new(Demo::UserIdentity.new(gender: 'female')).gender).to eq('Féminin')
      expect(described_class.new(Demo::UserIdentity.new(gender: 'male')).gender).to eq('Masculin')
      expect(described_class.new(Demo::UserIdentity.new(gender: 'unspecified')).gender).to eq('Non précisé')
    end

    it 'says nothing at all when the answer carried none' do
      expect(described_class.new(Demo::UserIdentity.new).gender).to be_nil
    end
  end
end
