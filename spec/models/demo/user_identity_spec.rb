require 'rails_helper'

RSpec.describe Demo::UserIdentity do
  subject(:identity) { described_class.new(**attributes) }

  let(:attributes) do
    { given_name: 'Freja Marie', family_name: 'Sørensen', birthdate: '2001-04-17',
      level_of_assurance: 'Substantial', subject: 'un-pseudonyme', id_token: 'le-jeton-signe' }
  end

  it 'is valid on the minimum data set alone, with no identifier' do
    expect(identity).to be_valid
    expect(identity).not_to be_identified
  end

  %i[given_name family_name birthdate level_of_assurance subject id_token].each do |attribute|
    it "refuses an identity without #{attribute}" do
      expect(described_class.new(**attributes.except(attribute))).not_to be_valid
    end
  end

  # `R-EDM-REQ-C040` (FATAL) and the Schematron floor of six characters, held
  # once for the three subjects that carry an eIDAS identifier.
  describe 'the eIDAS identifier' do
    it 'admits the shape a Member State asserts' do
      expect(described_class.new(**attributes, eidas_identifier: 'DK/FR/61f6a1b0')).to be_valid
    end

    it 'refuses one the specification would make the request be refused for' do
      refused = described_class.new(**attributes, eidas_identifier: 'DK-FR-61f6a1b0')

      expect(refused).not_to be_valid
      expect(refused.errors.full_messages.join).to include('PAYS/PAYS/IDENTIFIANT')
    end
  end

  it 'refuses a level of assurance the code list does not publish, naming the three' do
    refused = described_class.new(**attributes, level_of_assurance: 'Medium')

    expect(refused.errors.tap { refused.valid? }.full_messages.join)
      .to include('Medium', 'Low, Substantial, High')
  end

  it 'refuses a date of birth that is not the ISO 8601 the chapter imposes' do
    expect(described_class.new(**attributes, birthdate: '17/04/2001')).not_to be_valid
  end

  # Held in the portal's own lower case, which is what the beneficiary token
  # carries and what the requester translates.
  it 'refuses a sex FranceConnect+ does not publish' do
    expect(described_class.new(**attributes, gender: 'Female')).not_to be_valid
    expect(described_class.new(**attributes, gender: 'female')).to be_valid
  end

  # The session cookie holds JSON and gives back string keys.
  describe 'the round trip through the session' do
    it 'keeps every attribute it held' do
      stored = described_class.new(**attributes, gender: 'female').to_session

      expect(described_class.from_session(stored.stringify_keys))
        .to have_attributes(family_name: 'Sørensen', gender: 'female', id_token: 'le-jeton-signe')
    end

    it 'holds nothing where nothing was given' do
      expect(identity.to_session.keys).not_to include('gender', 'eidas_identifier')
    end

    it 'gives back nothing when the session holds nothing' do
      expect(described_class.from_session(nil)).to be_nil
    end
  end
end
