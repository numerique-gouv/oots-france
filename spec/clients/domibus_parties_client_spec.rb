require 'rails_helper'

RSpec.describe DomibusPartiesClient do
  subject(:client) { described_class.new }

  let(:base_url) { 'http://domibus:8080/domibus' }
  let(:listing) { "#{base_url}/ext/party" }

  before do
    allow(Settings).to receive_messages(
      domibus_base_url: base_url,
      domibus_credentials: { login: 'oots', password: 'secret' },
    )
  end

  def answering(parties) = { body: parties.to_json, headers: { 'Content-Type' => 'application/json' } }

  it 'reads every party, with its identifier, its scheme and its MSH' do
    stub_request(:get, listing).with(query: { pageStart: 0, pageSize: 100 }, basic_auth: %w[oots secret])
      .to_return(answering(gateway_parties))

    expect(client.parties.size).to eq(12)
    expect(client.parties.find { |party| party.name == 'AP_EL_01' }).to have_attributes(
      identifier: 'AP_EL_01', identifier_type: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:EL',
      endpoint: 'https://as4.oots.example.gr/domibus/services/msh',
    )
  end

  # The resource gives ten parties when asked nothing: the list is read page
  # after page, by offset, until one comes back short.
  it 'reads past one page' do
    stub_const('DomibusPartiesClient::PAGE_SIZE', 10)
    stub_request(:get, listing).with(query: { pageStart: 0, pageSize: 10 })
      .to_return(answering(gateway_parties.first(10)))
    stub_request(:get, listing).with(query: { pageStart: 10, pageSize: 10 })
      .to_return(answering(gateway_parties.drop(10)))

    expect(client.parties.map(&:name)).to eq(gateway_parties.pluck('name'))
  end

  it 'says the gateway refused the Plugin User' do
    stub_request(:get, listing).with(query: hash_including({})).to_return(status: 401)

    expect { client.parties }.to raise_error(GatewayError) { |error| expect(error).to be_refused }
  end

  it 'says the gateway did not answer when what it answers is no list' do
    stub_request(:get, listing).with(query: hash_including({})).to_return(body: '<html>Login</html>')

    expect { client.parties }.to raise_error(GatewayError) { |error| expect(error).not_to be_refused }
  end

  it 'says the gateway did not answer when its JSON is no list' do
    stub_request(:get, listing).with(query: hash_including({})).to_return(answering({ 'message' => 'error' }))

    expect { client.parties }.to raise_error(GatewayError) { |error| expect(error).not_to be_refused }
  end

  it 'says the gateway did not answer' do
    stub_request(:get, listing).with(query: hash_including({})).to_raise(Faraday::ConnectionFailed.new('refused'))

    expect { client.parties }.to raise_error(GatewayError) { |error| expect(error).not_to be_refused }
  end
end
