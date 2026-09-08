require 'rails_helper'

# The list `R-EDM-REQ-C108` holds the `lang` of a requesting agent's name to,
# and `R-EDM-ERR-C028` the same attribute once France writes it back.
RSpec.describe LanguageCode do
  it 'accepts the two codes France writes itself' do
    expect(described_class).to be_valid('FR')
    expect(described_class).to be_valid('EN')
  end

  it 'refuses a code the list does not publish' do
    expect(described_class).not_to be_valid('xx')
  end

  # `.=$code` carries no `i` flag, where `R-EDM-REQ-C040` carries one: the case
  # of a language code decides an exchange, and the list publishes upper case.
  it 'refuses a published code written in lower case, the comparison being exact' do
    expect(described_class).not_to be_valid('fr')
  end

  it 'refuses a code padded with blanks, the rule normalising nothing here' do
    expect(described_class).not_to be_valid(' FR ')
  end

  it 'refuses nil, which is what an absent attribute reads as' do
    expect(described_class).not_to be_valid(nil)
  end

  # ISO 639-1 codes Greek `EL` in this list, as the country list codes Greece.
  it 'accepts EL, which is how the list codes Greek' do
    expect(described_class).to be_valid('EL')
  end

  # The published list names several languages twice, once per ISO 639-2
  # variant; what is held here is that list with its duplicates removed.
  it 'holds the published list, deduplicated' do
    expect(described_class::CODES.size).to eq(184)
    expect(described_class::CODES.uniq).to eq(described_class::CODES)
  end
end
