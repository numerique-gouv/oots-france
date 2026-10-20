require 'rails_helper'

RSpec.describe PmodeParty do
  def party(identifier_type) = described_class.new(name: 'p', identifier: 'p', identifier_type:, endpoint: nil)

  let(:known) { %w[EL FR] }

  def certificate(country) = TruststoreEntry.new(name: 'p', subject: ['CN=p', country].compact.join(', '))

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

  it 'reads the country a member state\'s scheme ends with, whatever its certificate says' do
    expect(party('urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL').country_code(known, certificate: certificate('C=FR')))
      .to eq('EL')
  end

  it 'reads the country of the certificate for an EAS scheme' do
    expect(party('urn:cef.eu:names:identifier:EAS:0190').country_code(known, certificate: certificate('C=FR'))).to eq('FR')
    expect(party('urn:cef.eu:names:identifier:EAS:0190').country_code(known, certificate: certificate('C=GR'))).to eq('EL')
  end

  it 'reads no country for an EAS scheme without a certificate, without a country, or of a code the list does not carry' do
    eas = party('urn:cef.eu:names:identifier:EAS:0190')

    expect(eas.country_code(known)).to be_nil
    expect(eas.country_code(known, certificate: certificate(nil))).to be_nil
    expect(eas.country_code(known, certificate: certificate('C=US'))).to be_nil
  end

  it 'reads no country from a certificate under any other scheme' do
    expect(party('urn:example:scheme').country_code(known, certificate: certificate('C=FR'))).to be_nil
  end

  it 'reads no country for a code the list does not carry' do
    expect(party('urn:oasis:names:tc:ebcore:partyid-type:unregistered:LI').country_code(known)).to be_nil
  end
end
