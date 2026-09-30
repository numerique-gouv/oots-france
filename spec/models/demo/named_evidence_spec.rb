require 'rails_helper'

RSpec.describe Demo::NamedEvidence do
  subject(:named) { described_class.new(attributes) }

  let(:attributes) do
    { evidence_type_name: 'Dummy PDF - FI', evidence_type_language: 'EN',
      provider_name: 'Keha v. 2.0', provider_language: 'EN',
      requirement_id: 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000',
      requirement_name: '(TEST) Test Requirement', requirement_language: 'EN', country_code: 'FI' }
  end

  # Requirement 27 of chapter 1 §2 — « The user is provided with information
  # about name of evidence provider and evidence type for confirmation, before
  # any request is made. » — which is the condition of the request and not a
  # check on a form: unable to name the two, the click may not leave.
  describe 'validations' do
    it 'holds what requirement 27 had the card show' do
      expect(named).to be_valid
    end

    it 'refuses a card that cannot name the evidence type' do
      expect(described_class.new(attributes.merge(evidence_type_name: nil))).not_to be_valid
    end

    it 'refuses a card that cannot name the provider' do
      expect(described_class.new(attributes.merge(provider_name: nil))).not_to be_valid
    end

    # The two names are what one member state publishes, and the request goes
    # to that one: named without it, they say nothing of where to ask.
    it 'refuses a card that cannot name the country it was resolved in' do
      expect(described_class.new(attributes.merge(country_code: nil))).not_to be_valid
    end

    # The requirement tells two cards apart; it is not one of the two names the
    # user confirms, and a directory naming it in no language leaves the card
    # standing under its evidence type.
    it 'accepts a card the Evidence Broker named in no language' do
      expect(described_class.new(attributes.merge(requirement_name: nil, requirement_language: nil))).to be_valid
    end
  end

  # `Demo::RequestEvidence::NAMED` reads each of these off its context under this
  # very name, and `demo_requests` has a column per attribute: one vocabulary
  # from the card to the row.
  it 'names its attributes as the request carries them' do
    expect(named.attributes.keys + Demo::NamedProcedure.new.attributes.keys)
      .to match_array(Demo::RequestEvidence::NAMED.map(&:to_s))
  end
end
