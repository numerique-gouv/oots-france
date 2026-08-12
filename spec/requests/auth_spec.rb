require 'rails_helper'

RSpec.describe 'GET /auth/cles_publiques' do
  let(:rsa) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    allow(Settings).to receive(:private_key_jwk)
      .and_return(JWT::JWK.new(rsa).export(include_private: true).transform_keys(&:to_s))
  end

  it 'serves the key set as JSON' do
    get '/auth/cles_publiques'

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('application/json')
  end

  it 'serves a key set a client can actually use to encrypt for us' do
    get '/auth/cles_publiques'

    published = JWT::JWK.new(response.parsed_body['keys'].first)
    encrypted = JWE.encrypt('secret', published.verify_key, alg: 'RSA-OAEP-256', enc: 'A256GCM')

    expect(JWE.decrypt(encrypted, rsa)).to eq('secret')
  end

  # The route this replaces enumerated the members of an RSA key while the key
  # configured was an EC one: the identifier could not be computed and the route
  # failed outright. It was never caught, because the unit test injected a fake
  # RSA key *and* replaced the hashing, while the end-to-end test derived the
  # public key from the private one instead of calling the route.
  #
  # This one asks the route, whatever the key type.
  context 'with an elliptic-curve key' do
    let(:rsa) { OpenSSL::PKey::EC.generate('prime256v1') }

    it 'serves it rather than failing' do
      get '/auth/cles_publiques'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['keys'].first).to include('kty' => 'EC')
    end
  end

  it 'never serves a private member' do
    get '/auth/cles_publiques'

    expect(response.parsed_body['keys'].first.keys).not_to include(*PublicKeySet::SECRET_MEMBERS)
    expect(response.body).not_to include(JWT::JWK.new(rsa).export(include_private: true)[:d])
  end
end
