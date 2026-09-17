require 'rails_helper'

RSpec.describe Demo::NamedEvidence do
  subject(:named) { described_class.new(attributes) }

  let(:attributes) do
    { evidence_type_name: 'Dummy PDF - FI', evidence_type_language: 'EN',
      provider_name: 'Keha v. 2.0', provider_language: 'EN',
      requirement_id: 'https://sr.acc.oots.tech.ec.europa.eu/requirements/00000000-0000-0000-0000-000000000000',
      requirement_name: '(TEST) Test Requirement', requirement_language: 'EN' }
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

    # The requirement tells two cards apart; it is not one of the two names the
    # user confirms, and a directory naming it in no language leaves the card
    # standing under its evidence type.
    it 'accepts a card the Evidence Broker named in no language' do
      expect(described_class.new(attributes.merge(requirement_name: nil, requirement_language: nil))).to be_valid
    end
  end

  describe '.from_session' do
    it 'reads back the string keys the cookie gives' do
      expect(described_class.from_session(named.to_session)).to have_attributes(attributes)
    end

    # A session written before this shape existed, and one holding nothing at
    # all, land on the same value: names nobody can read are no names, and the
    # click is sent back to the page that says them.
    it 'names nothing of a session written under an earlier shape' do
      expect(described_class.from_session('evidence_type' => 'Dummy PDF - FI')).not_to be_valid
    end

    it 'names nothing when the session holds nothing' do
      expect(described_class.from_session(nil)).not_to be_valid
    end
  end

  # The cookie store bounds the session at four kibibytes and a page holds one
  # entry per card, so a language no directory published is worth no bytes.
  describe '#to_session' do
    it 'leaves out what no directory named' do
      expect(described_class.new(evidence_type_name: 'Dummy PDF - FI').to_session)
        .to eq('evidence_type_name' => 'Dummy PDF - FI')
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
