require 'rails_helper'

RSpec.describe ProConnectClient do
  subject!(:client) { described_class.new(instance: stub_pro_connect) }

  def query(url) = URI.decode_www_form(URI.parse(url).query).to_h

  it 'builds the authorization address on the published endpoint, with the six parameters and no seventh' do
    url = client.authorization_url(state: 's' * 32, nonce: 'n' * 32)

    expect(url).to start_with(ProConnectStubs::AUTHORIZATION_ENDPOINT)
    expect(query(url)).to eq('response_type' => 'code', 'client_id' => ProConnectStubs::CLIENT_ID,
      'redirect_uri' => "#{ProConnectStubs::CONSOLE_URL}/admin/proconnect/retour_connexion",
      'scope' => 'openid email', 'state' => 's' * 32, 'nonce' => 'n' * 32)
  end

  it 'presents the code to /token with the credentials in the body' do
    stub_pro_connect_tokens('un.id.token')

    expect(client.exchange('un-code')).to include('access_token' => 'un-jeton-d-acces', 'id_token' => 'un.id.token')
    expect(a_request(:post, ProConnectStubs::TOKEN_ENDPOINT)
      .with(body: hash_including('client_secret' => ProConnectStubs::CLIENT_SECRET, 'redirect_uri' =>
        "#{ProConnectStubs::CONSOLE_URL}/admin/proconnect/retour_connexion"))).to have_been_made
  end

  it 'refuses an answer of /token that carries no ID Token' do
    stub_request(:post, ProConnectStubs::TOKEN_ENDPOINT).to_return(body: { access_token: 'a' }.to_json)

    expect { client.exchange('un-code') }.to raise_error(ProConnectError, /id_token/)
  end

  it 'answers the UserInfo body with the type it came in' do
    stub_pro_connect_userinfo({ 'sub' => 'x' }, form: :json)

    expect(client.userinfo('un-jeton')).to eq([{ 'sub' => 'x' }.to_json, 'application/json'])
  end

  it 'builds the end of session on the published endpoint, back to the declared address' do
    url = client.end_session_url(id_token_hint: 'un.id.token', state: 's' * 32)

    expect(url).to start_with(ProConnectStubs::END_SESSION_ENDPOINT)
    expect(query(url)).to eq('id_token_hint' => 'un.id.token', 'state' => 's' * 32,
      'post_logout_redirect_uri' => "#{ProConnectStubs::CONSOLE_URL}/admin/proconnect/retour_deconnexion")
  end

  # `OpenidDiscovery` is FranceConnect+'s defence too, and its specs prove it in
  # full; this one proves ProConnect is behind it.
  it 'refuses an endpoint the document publishes off the configured issuer' do
    instance = stub_pro_connect
    stub_request(:get, "#{ProConnectStubs::ISSUER}#{described_class::DISCOVERY_PATH}")
      .to_return(body: pro_connect_discovery.merge(token_endpoint: 'http://ailleurs.test/token').to_json)

    expect { described_class.new(instance:).exchange('un-code') }
      .to raise_error(ProConnectError, /hors de proconnect\.test/)
  end

  it 'refuses a document that names another issuer' do
    instance = stub_pro_connect
    stub_request(:get, "#{ProConnectStubs::ISSUER}#{described_class::DISCOVERY_PATH}")
      .to_return(body: pro_connect_discovery.merge(issuer: 'http://ailleurs.test').to_json)

    expect { described_class.new(instance:).issuer }.to raise_error(ProConnectError, /ailleurs\.test/)
  end
end
