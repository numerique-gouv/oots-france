require 'rails_helper'

# The list `R-EDM-REQ-C016` holds an agent's `sdg:AdminUnitLevel2` to, where
# `CountryIdentificationCode` answers the `AdminUnitLevel1` above it.
RSpec.describe NutsCode do
  it 'accepts a code the list publishes' do
    expect(described_class).to be_valid('FR101')
  end

  it 'refuses a code the list does not publish' do
    expect(described_class).not_to be_valid('FR999')
  end

  # The assertion is an `=` with no `i` flag, exactly as `R-EDM-REQ-C015`.
  it 'refuses a published code written in lower case' do
    expect(described_class).not_to be_valid('fr101')
  end

  it 'refuses nil, which is what a missing element reads as' do
    expect(described_class).not_to be_valid(nil)
  end

  # All four levels of the nomenclature at once, the rule comparing to the flat
  # list: an agent naming its region alone is as conformant as one naming the
  # commune. A reader that asked for five characters would refuse both.
  it 'carries every level of the nomenclature' do
    expect(described_class).to be_valid('FR')
    expect(described_class).to be_valid('FR1')
    expect(described_class).to be_valid('FR10')
    expect(described_class).to be_valid('FR101')
  end

  # The nomenclature codes Greece `EL`, as `CountryIdentificationCode` does, and
  # carries countries that take no part in OOTS.
  it 'follows the Union usage and reaches beyond its members' do
    expect(described_class).to be_valid('EL')
    expect(described_class).to be_valid('UKN01')
    expect(described_class).not_to be_valid('GR')
  end

  it 'holds the published list whole' do
    expect(described_class::CODES.size).to eq(3332)
  end
end
