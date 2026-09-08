require 'rails_helper'

# The list `R-EDM-REQ-C015` holds an agent's `sdg:AdminUnitLevel1` to, and its
# response and error counterparts `R-EDM-RESP-C008` and `R-EDM-ERR-C005`.
RSpec.describe CountryIdentificationCode do
  it 'accepts the country France declares itself under' do
    expect(described_class).to be_valid('FR')
  end

  it 'refuses a code the list does not publish' do
    expect(described_class).not_to be_valid('ZZ')
  end

  # The assertion is an `=` with no `i` flag, exactly as `R-EDM-REQ-C108`.
  it 'refuses a published code written in lower case' do
    expect(described_class).not_to be_valid('fr')
  end

  it 'refuses nil, which is what a missing element reads as' do
    expect(described_class).not_to be_valid(nil)
  end

  # The list follows the Union's usage rather than ISO 3166-1 unamended: a
  # reader taking `GR` for Greece would refuse a conformant Greek requester and
  # accept a code the rule does not publish.
  it 'codes Greece EL and not GR' do
    expect(described_class).to be_valid('EL')
    expect(described_class).not_to be_valid('GR')
  end

  # Wider than `IdentifierScheme::UNREGISTERED_CODES`, which carries the
  # countries taking part in OOTS: the two answer different rules and must not
  # be merged.
  it 'carries countries no OOTS list does' do
    expect(described_class).to be_valid('JP')
    expect(IdentifierScheme::UNREGISTERED_CODES).not_to include('JP')
  end

  it 'holds the published list whole' do
    expect(described_class::CODES.size).to eq(249)
  end
end
