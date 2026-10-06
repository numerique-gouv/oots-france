require 'rails_helper'

RSpec.describe PmodeParty do
  def party(identifier_type) = described_class.new(name: 'p', identifier: 'p', identifier_type:, endpoint: nil)

  let(:known) { %w[EL FR] }

  it 'is addressable by an identifier and its scheme, and by nothing less' do
    expect(party('urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL')).to be_addressable
    expect(party(nil)).not_to be_addressable
    expect(described_class.new(name: 'p', identifier: nil, identifier_type: 'x', endpoint: nil)).not_to be_addressable
  end

  it 'reads the country a member state\'s scheme ends with' do
    expect(party('urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL').country_code(known)).to eq('EL')
  end

  it 'reads no country for the Commission\'s platforms' do
    expect(party('urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots').country_code(known)).to be_nil
  end

  it 'reads no country for an EAS scheme, a member state\'s included' do
    expect(party('urn:cef.eu:names:identifier:EAS:0190').country_code(known)).to be_nil
  end

  it 'reads no country for a code the list does not carry' do
    expect(party('urn:oasis:names:tc:ebcore:partyid-type:unregistered:LI').country_code(known)).to be_nil
  end
end
