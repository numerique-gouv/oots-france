require 'rails_helper'

RSpec.describe NaturalPerson do
  it { is_expected.to validate_presence_of(:family_name) }
  it { is_expected.to validate_presence_of(:given_name) }
  it { is_expected.to validate_presence_of(:date_of_birth) }

  # The date travels into `sdg:DateOfBirth`, which the TDD type as a date. A
  # French-formatted one would pass through the templates untouched and be
  # rejected by the correspondent, far from where it was introduced.
  it 'rejects a date that is not ISO 8601' do
    expect(build(:natural_person, date_of_birth: '25/11/1965')).not_to be_valid
  end

  it 'accepts an ISO 8601 date' do
    expect(build(:natural_person)).to be_valid
  end

  # The eIDAS identifier is optional: this deployment receives it from the
  # requester's token, which does not always carry one.
  it 'is valid without an eIDAS identifier' do
    expect(build(:natural_person, eidas_identifier: nil)).to be_valid
  end
end
