require 'rails_helper'

RSpec.describe StudentStatus::CardIdentity do
  subject(:card_identity) do
    described_class.from(StudentStatus::Identity.new(family_name: 'Martin', given_name: 'Jacques',
      date_of_birth: '2004-01-01'))
  end

  it 'reads the date of birth where the card reads it' do
    expect(card_identity).to have_attributes(family_name: 'Martin', given_name: 'Jacques', birthdate: '2004-01-01')
  end

  it 'yields none of what the registry does not hold' do
    expect(card_identity).to have_attributes(gender: nil, place_of_birth: nil, level_of_assurance: nil,
      eidas_identifier: nil)
  end
end
