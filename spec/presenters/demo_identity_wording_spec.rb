require 'rails_helper'

RSpec.describe DemoIdentityWording do
  subject(:wording) { described_class.new(identity) }

  let(:identity) { Demo::UserIdentity.new(**attributes) }
  let(:attributes) { { provenance: 'eidas' } }

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

  # RG6: no claim names the country or the foreign identity provider, so the
  # screen names neither — only the path the identity took.
  describe '#provenance' do
    it 'names the bridge, and no country' do
      expect(wording.provenance).to include('autre État membre', 'eIDAS')
      expect(wording.provenance).not_to include('Danemark')
    end

    it 'says the provenance is not attested when the claim did not say it' do
      expect(described_class.new(Demo::UserIdentity.new).provenance).to include('non attestée')
    end
  end

  # The nominal case today, and a sentence rather than an empty cell: an empty
  # line would read as an oversight.
  describe '#eidas_identifier' do
    it 'says it was not returned when none was' do
      expect(wording.eidas_identifier).to include('Non rendu')
    end

    it 'says the one that was, exactly as it came' do
      identity.eidas_identifier = 'DK/FR/61f6a1b0'

      expect(wording.eidas_identifier).to eq('DK/FR/61f6a1b0')
    end
  end
end
