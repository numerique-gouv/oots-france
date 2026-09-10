require 'rails_helper'

RSpec.describe Demo::StartIdentification do
  subject(:result) { described_class.call }

  before { stub_france_connect }

  it 'builds the address the browser departs on' do
    expect(result).to be_a_success
    expect(result.authorization_url).to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
  end

  # RG8 asks for at least thirty-two characters on both, and the return is
  # checked against what is drawn here.
  it 'draws a state and a nonce of thirty-two characters, and puts them in the address' do
    parameters = URI.decode_www_form(URI.parse(result.authorization_url).query).to_h

    expect(result.state.length).to eq(32)
    expect(result.nonce.length).to eq(32)
    expect(parameters.values_at('state', 'nonce')).to eq([result.state, result.nonce])
  end

  it 'draws a new pair on every departure' do
    expect(described_class.call.state).not_to eq(result.state)
  end

  it 'refuses a discovery document that publishes no authorization endpoint' do
    stub_request(:get, FranceConnectStubs::DISCOVERY_URL)
      .to_return(body: discovery_document.except(:authorization_endpoint).to_json)

    expect(result).to be_a_failure
    expect(result.authorization_url).to be_nil
  end

  # The operator is told, and holds nothing: a departure that could not be built
  # is not one to be sent on.
  it 'refuses when FranceConnect+ does not answer its own discovery' do
    stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_timeout

    expect(result).to be_a_failure
    expect(result.error[:key]).to eq(:identification_refused)
    expect(result.error[:errors].join).to include('découverte')
    expect(result.authorization_url).to be_nil
  end

  it 'leaves a trace of the refusal on the server' do
    stub_code_list
    stub_request(:get, FranceConnectStubs::DISCOVERY_URL).to_timeout
    allow(Rails.logger).to receive(:warn)

    expect(result).to be_a_failure
    expect(Rails.logger).to have_received(:warn).with(/découverte/)
  end
end
