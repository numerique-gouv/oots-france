require 'rails_helper'

RSpec.describe Demo::Card do
  let(:card) do
    { country_code: 'EL', evidence_type_list_id: 'ensemble',
      requirement_id: 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000' }
  end
  let(:lines) do
    [Demo::NamedEvidence.new(evidence_type_id: 'https://sr/EL/projectathon', evidence_type_name: 'Projectathon test evidence',
      provider_name: 'Ministry', provider_classifications: { 'question' => 'TC03' }),
     Demo::NamedEvidence.new(evidence_type_id: 'https://sr/EL/simple', evidence_type_name: 'Simple test evidence',
       provider_name: 'Ministry of Digital Governance')]
  end

  def remember(card = self.card, lines = self.lines, journey_id: 'parcours', requirement_uuid: 'exigence')
    described_class.remember(journey_id:, requirement_uuid:, card:, lines:)
  end

  describe '.remember' do
    it 'writes one row per card, and writes it again on the next choice' do
      remember
      remember({ country_code: 'DE' }, [])

      expect(described_class.sole).to have_attributes(country_code: 'DE', evidence_type_list_id: nil, evidence_types: [])
    end

    # Chapter 4.4 §4.2.2: a card never writes over its neighbour.
    it 'leaves the neighbouring card as it was' do
      remember(requirement_uuid: 'premiere')
      remember({ country_code: 'DE' }, [], requirement_uuid: 'seconde')

      expect(described_class.countries('parcours')).to eq('premiere' => 'EL', 'seconde' => 'DE')
    end
  end

  describe '#named_evidences' do
    # Chapter 3.2.2 §2.3: one request per evidence type of the combination.
    it 'gives back one per line, each with what the card itself named' do
      remember

      expect(described_class.sole.named_evidences).to contain_exactly(
        have_attributes(evidence_type_name: 'Projectathon test evidence', country_code: 'EL',
          evidence_type_list_id: 'ensemble', provider_classifications: { 'question' => 'TC03' }).and(be_valid),
        have_attributes(evidence_type_name: 'Simple test evidence', provider_classifications: {}).and(be_valid),
      )
    end

    # Requirement 27 of chapter 1 §2 makes the two names a condition of the
    # request: a line that named nothing holds nothing a click may leave on.
    it 'names nothing of a line that named nothing' do
      remember(card, [Demo::NamedEvidence.new(evidence_type_id: 'https://sr/EL/simple')])

      expect(described_class.sole.named_evidences.sole).not_to be_valid
    end
  end

  describe '.provider_classifications' do
    it 'gives the answers of each card, by evidence type' do
      remember

      expect(described_class.provider_classifications('parcours'))
        .to eq('exigence' => { 'projectathon' => { 'question' => 'TC03' } })
    end
  end

  describe '.evidence_type_lists' do
    it 'gives the combination of each card that names one' do
      remember(requirement_uuid: 'premiere')
      remember({ country_code: 'DE' }, [], requirement_uuid: 'seconde')

      expect(described_class.evidence_type_lists('parcours')).to eq('premiere' => 'ensemble')
    end
  end

  describe '.forget' do
    it 'drops the cards of one journey and no other' do
      remember(journey_id: 'ancien')
      remember(journey_id: 'autre')

      described_class.forget('ancien')

      expect(described_class.pluck(:journey_id)).to eq(['autre'])
    end
  end
end
