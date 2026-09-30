require 'rails_helper'

RSpec.describe Demo::Card do
  let(:named) do
    Demo::NamedEvidence.new(evidence_type_name: 'Dummy PDF - FI', provider_name: 'Keha v. 2.0', country_code: 'FI',
      requirement_id: 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000')
  end

  def remember(named_evidence, journey_id: 'parcours', requirement_uuid: 'exigence')
    described_class.remember(journey_id:, requirement_uuid:, named_evidence:)
  end

  describe '.remember' do
    it 'writes one row per card, and writes it again on the next choice' do
      remember(named)
      remember(Demo::NamedEvidence.new(country_code: 'DE'))

      expect(described_class.sole).to have_attributes(country_code: 'DE', provider_name: nil, evidence_type_name: nil)
    end

    # Chapter 4.4 §4.2.2: a card never writes over its neighbour.
    it 'leaves the neighbouring card as it was' do
      remember(named, requirement_uuid: 'premiere')
      remember(Demo::NamedEvidence.new(country_code: 'DE'), requirement_uuid: 'seconde')

      expect(described_class.countries('parcours')).to eq('premiere' => 'FI', 'seconde' => 'DE')
    end
  end

  describe '#named_evidence' do
    it 'gives back what the card named' do
      remember(named)

      expect(described_class.sole.named_evidence).to have_attributes(named.attributes.symbolize_keys).and be_valid
    end

    # Requirement 27 of chapter 1 §2 makes the two names a condition of the
    # request: a card that named nothing holds nothing a click may leave on.
    it 'names nothing of a card that named nothing' do
      remember(Demo::NamedEvidence.new(country_code: 'DE'))

      expect(described_class.sole.named_evidence).not_to be_valid
    end
  end

  describe '.forget' do
    it 'drops the cards of one journey and no other' do
      remember(named, journey_id: 'ancien')
      remember(named, journey_id: 'autre')

      described_class.forget('ancien')

      expect(described_class.pluck(:journey_id)).to eq(['autre'])
    end
  end
end
