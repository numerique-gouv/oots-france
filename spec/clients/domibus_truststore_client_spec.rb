require 'rails_helper'

RSpec.describe DomibusTruststoreClient do
  subject(:client) { described_class.new }

  let(:entries) { 'http://domibus:8080/domibus/ext/truststore/entries' }

  before do
    allow(Settings).to receive_messages(
      domibus_base_url: 'http://domibus:8080/domibus',
      domibus_credentials: { login: 'oots', password: 'secret' },
    )
  end

  it 'reads every certificate, with the alias it is stored under and its subject' do
    stub_request(:get, entries).with(basic_auth: %w[oots secret])
      .to_return(body: gateway_truststore.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(client.entries.map(&:name)).to eq(%w[ap_fr_01 ap_el_01 ec_support_acc ap_nl_01])
    expect(client.entries.last).to have_attributes(subject: 'CN=AP_NL_01, OU=OOTS, O=Logius, C=NL')
  end

  it 'says the gateway refused the Plugin User' do
    stub_request(:get, entries).to_return(status: 403)

    expect { client.entries }.to raise_error(GatewayError) { |error| expect(error).to be_refused }
  end

  it 'says the gateway did not answer' do
    stub_request(:get, entries).to_return(status: 500)

    expect { client.entries }.to raise_error(GatewayError) { |error| expect(error).not_to be_refused }
  end

  it 'says the gateway did not answer when what it answers is no list' do
    stub_request(:get, entries).to_return(body: { 'message' => 'error' }.to_json)

    expect { client.entries }.to raise_error(GatewayError) { |error| expect(error).not_to be_refused }
  end

  it 'says the gateway did not answer when its list holds no entries' do
    stub_request(:get, entries).to_return(body: [1, nil].to_json)

    expect { client.entries }.to raise_error(GatewayError) { |error| expect(error).not_to be_refused }
  end
end
