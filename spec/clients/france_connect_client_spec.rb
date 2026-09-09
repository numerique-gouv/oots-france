require 'rails_helper'

RSpec.describe FranceConnectClient do
  subject(:client) { described_class.new }

  before { stub_france_connect }

  # Every address comes from the discovery document and none is built here:
  # that is what makes the sandbox, the production and the fake a change of
  # environment rather than of code.
  describe 'what it knows of FranceConnect+' do
    it 'reads the issuer and the key set from the document it publishes' do
      expect(client.issuer).to eq(FranceConnectStubs::ISSUER)
      expect(client.jwks_url).to eq(FranceConnectStubs::JWKS_URL)
    end

    it 'reads the document once and holds it' do
      3.times { client.authorization_url(state: 's' * 32, nonce: 'n' * 32) }

      expect(a_request(:get, FranceConnectStubs::DISCOVERY_URL)).to have_been_made.once
    end

    # Declared to FranceConnect+, which refuses an address it was not given:
    # derived from this deployment's own URL and never from the request.
    it 'names the two declared addresses under the procedure URL' do
      expect(client.redirect_uri).to eq('http://oots.test/demo/franceconnect/retour_connexion')
      expect(client.post_logout_redirect_uri).to eq('http://oots.test/demo/franceconnect/retour_deconnexion')
    end
  end

  describe '#authorization_url' do
    subject(:parameters) do
      URI.decode_www_form(URI.parse(client.authorization_url(state: 's' * 32, nonce: 'n' * 32)).query).to_h
    end

    it 'opens the European flow, straight to the country page' do
      expect(parameters).to include('idp_hint' => 'eidas-bridge', 'response_type' => 'code',
        'acr_values' => 'eidas2')
    end

    it 'asks for the minimum data set and the two optional attributes' do
      expect(parameters.fetch('scope').split)
        .to contain_exactly('openid', 'given_name', 'family_name', 'birthdate', 'gender', 'birthplace')
    end

    # No scope covers it: it is the essential-claims mechanism that asks for it,
    # and it is what says the identity came through the eIDAS bridge.
    it 'asks for the authentication method as an essential claim' do
      expect(JSON.parse(parameters.fetch('claims'))).to eq('id_token' => { 'amr' => { 'essential' => true } })
    end

    it 'carries the state and the nonce it is given, and both are 32 characters' do
      expect(parameters.values_at('state', 'nonce')).to eq(['s' * 32, 'n' * 32])
    end

    # A parameter FranceConnect+ does not know is refused outright, without even
    # a redirection: nothing may be added here on a hunch.
    it 'sends nothing FranceConnect+ does not declare' do
      expect(parameters.keys).to contain_exactly('client_id', 'response_type', 'redirect_uri', 'scope',
        'state', 'nonce', 'acr_values', 'claims', 'idp_hint')
    end

    it 'departs from the endpoint the document publishes' do
      expect(client.authorization_url(state: 's', nonce: 'n'))
        .to start_with("#{FranceConnectStubs::AUTHORIZATION_ENDPOINT}?")
    end
  end

  # `client_secret_post`: the credentials travel in the body, FranceConnect+
  # accepting no `Authorization: Basic` here.
  describe '#exchange' do
    before { stub_france_connect_tokens(france_connect_id_token_claims) }

    it 'presents the code, the redirect address and the credentials in the body' do
      client.exchange('un-code')

      expect(a_request(:post, FranceConnectStubs::TOKEN_ENDPOINT).with do |request|
        URI.decode_www_form(request.body).to_h.then do |body|
          body.values_at('grant_type', 'code', 'client_id', 'client_secret', 'redirect_uri') ==
            ['authorization_code', 'un-code', 'oots-france-demarche', 'secret-de-la-demarche',
             client.redirect_uri]
        end
      end).to have_been_made
    end

    it 'gives back what the endpoint answered' do
      expect(client.exchange('un-code')).to include('access_token' => 'un-jeton-d-acces')
    end

    it 'raises on a refusal rather than reading an error as a token' do
      stub_request(:post, FranceConnectStubs::TOKEN_ENDPOINT)
        .to_return(status: 400, body: { error: 'invalid_grant' }.to_json)

      expect { client.exchange('un-code') }.to raise_error(Faraday::Error)
    end
  end

  describe '#userinfo' do
    it 'presents the access token as a bearer, and hands back the sealed answer' do
      answer = client.userinfo('un-jeton-d-acces')

      expect(a_request(:get, FranceConnectStubs::USERINFO_ENDPOINT)
        .with(headers: { 'Authorization' => 'Bearer un-jeton-d-acces' })).to have_been_made
      expect(answer.split('.').size).to eq(5)
    end
  end

  describe '#end_session_url' do
    subject(:parameters) do
      URI.decode_www_form(URI.parse(client.end_session_url(id_token_hint: 'le-jeton', state: 'l-etat')).query).to_h
    end

    it 'carries the hint, the state and the declared return address' do
      expect(parameters).to eq('id_token_hint' => 'le-jeton', 'state' => 'l-etat',
        'post_logout_redirect_uri' => client.post_logout_redirect_uri)
    end
  end
end
