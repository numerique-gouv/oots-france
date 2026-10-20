require 'rails_helper'

RSpec.describe TruststoreEntry do
  def country(subject) = described_class.new(name: 'ap_nl_01', subject:).country_code

  it 'reads the country of a subject written as Java writes it' do
    expect(country('CN=AP_NL_01, OU=OOTS, O=Logius, C=NL')).to eq('NL')
    expect(country('CN=SDG-OOTS_Austria_AS4_Connector_Q, O=Bundesrechenzentrum GmbH, C=AT')).to eq('AT')
  end

  it 'reads the country beside the attributes Java names and OpenSSL does not' do
    expect(country('EMAILADDRESS=ap@example.si, SERIALNUMBER=123, CN=AP_SI_01, C=SI')).to eq('SI')
    expect(country('CN=AP_SI_01+O=Example, C=SI')).to eq('SI')
    expect(country('CN=AP_SI_01+C=SI, O=Example')).to eq('SI')
  end

  it 'reads no country from a subject without one' do
    expect(country('CN=AP_FR_01')).to be_nil
  end

  it 'reads Greece in the code of the country list' do
    expect(country('CN=AP_EL_01, C=GR')).to eq('EL')
  end

  it 'gives any other code as it is written' do
    expect(country('CN=AP_US_01, C=US')).to eq('US')
  end

  it 'takes no country quoted inside another attribute' do
    expect(country('CN="Foo, C=FR", O=Bar')).to be_nil
  end

  it 'takes no country escaped inside another attribute' do
    expect(country('CN=Foo\\, C=FR, O=Bar')).to be_nil
  end

  it 'reads no country from a subject that is no distinguished name, nor from none' do
    expect(country('not a distinguished name')).to be_nil
    expect(country(nil)).to be_nil
  end
end
