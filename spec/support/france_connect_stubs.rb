# FranceConnect+ as the demonstration procedure meets it: a discovery document,
# a JWKS, and tokens signed then encrypted for the key the procedure publishes.
#
# The endpoints are named from the discovery document alone, exactly as the
# client reads them — a double that answered a path the client built itself
# would prove the client right about a path nothing publishes.
module FranceConnectStubs
  # Pinned here and forced onto `Settings`, rather than read from the
  # environment: `.env.oots` reaches the container through `env_file` and would
  # otherwise decide what these examples assert.
  PROCEDURE_URL = 'http://oots.test'.freeze
  CLIENT_ID = 'oots-france-demarche'.freeze
  CLIENT_SECRET = 'secret-de-la-demarche'.freeze

  ISSUER = 'http://franceconnect.test/api/v2'.freeze
  DISCOVERY_URL = "#{ISSUER}/.well-known/openid-configuration".freeze
  AUTHORIZATION_ENDPOINT = "#{ISSUER}/authorize".freeze
  TOKEN_ENDPOINT = "#{ISSUER}/token".freeze
  USERINFO_ENDPOINT = "#{ISSUER}/userinfo".freeze
  JWKS_URL = "#{ISSUER}/jwks".freeze
  END_SESSION_ENDPOINT = "#{ISSUER}/session/end".freeze

  KEY_MANAGEMENT = 'RSA-OAEP-256'.freeze
  CONTENT_ENCRYPTION = 'A256GCM'.freeze

  # The Danish student the demonstration plays, with the two optional attributes
  # chapter 2.1 §2.4 lets a requester carry.
  DANISH_USERINFO = {
    'sub' => "#{'a' * 64}v1", 'given_name' => 'Freja Marie', 'family_name' => 'Sørensen',
    'birthdate' => '2001-04-17', 'gender' => 'female', 'birthplace' => 'Aarhus'
  }.freeze

  # What FranceConnect+ signs its tokens with, and the key it encrypts them for.
  def france_connect_signing_key = @france_connect_signing_key ||= OpenSSL::PKey::EC.generate('prime256v1')

  def procedure_key = @procedure_key ||= OpenSSL::PKey::RSA.generate(2048)

  def procedure_jwk
    JWT::JWK.new(procedure_key).export(include_private: true).transform_keys(&:to_s)
      .merge('alg' => KEY_MANAGEMENT)
  end

  def stub_france_connect(userinfo: DANISH_USERINFO)
    allow(Settings).to receive_messages(
      france_connect_private_key_jwk: procedure_jwk, france_connect_issuer: ISSUER,
      france_connect_credentials: { id: CLIENT_ID, secret: CLIENT_SECRET },
      oots_france_url: PROCEDURE_URL,
    )

    stub_request(:get, DISCOVERY_URL).to_return(body: discovery_document.to_json)
    stub_request(:get, JWKS_URL).to_return(body: france_connect_key_set.to_json)
    stub_france_connect_userinfo(userinfo)
  end

  def stub_france_connect_userinfo(claims)
    stub_request(:get, USERINFO_ENDPOINT)
      .to_return(body: sealed_for_procedure(claims), headers: { 'Content-Type' => 'application/jwt' })
  end

  def stub_france_connect_tokens(id_token_claims, access_token: 'un-jeton-d-acces')
    stub_request(:post, TOKEN_ENDPOINT).to_return(
      body: { access_token:, token_type: 'Bearer', expires_in: 60,
              id_token: sealed_for_procedure(id_token_claims) }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )
  end

  # The claims of an ID Token the procedure would accept, which each example
  # then spoils in the one way it is about.
  def france_connect_id_token_claims(**overrides)
    now = Time.current.to_i

    { 'iss' => ISSUER, 'sub' => DANISH_USERINFO.fetch('sub'),
      'aud' => CLIENT_ID, 'iat' => now, 'exp' => now + 60,
      'nonce' => 'le-nonce-de-depart', 'acr' => 'eidas2', 'amr' => %w[eidas] }.merge(overrides.stringify_keys)
  end

  # The whole European flow as a request spec walks it: the departure, whose
  # `state` and `nonce` are read off the address the browser is sent to — never
  # written into the session by hand, which would prove nothing about what ties
  # the return to the departure — and the return itself.
  def identify_demo_user(userinfo: DANISH_USERINFO, **id_token)
    stub_france_connect(userinfo:)
    post admin_demo_identification_path
    departure = URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h

    stub_france_connect_tokens(france_connect_id_token_claims(nonce: departure.fetch('nonce'), **id_token))

    get '/demo/franceconnect/retour_connexion', params: { code: 'un-code', state: departure.fetch('state') }
  end

  def discovery_document
    { issuer: ISSUER, authorization_endpoint: AUTHORIZATION_ENDPOINT, token_endpoint: TOKEN_ENDPOINT,
      userinfo_endpoint: USERINFO_ENDPOINT, jwks_uri: JWKS_URL,
      end_session_endpoint: END_SESSION_ENDPOINT }
  end

  def france_connect_key_set(key = france_connect_signing_key) = { keys: [JWT::JWK.new(key).export] }

  # Signed then encrypted, never the reverse: the procedure must be the only
  # reader, and the signature must survive inside what it opens.
  def sealed_for_procedure(claims, key: france_connect_signing_key, **encryption)
    signed = JWT.encode(claims, key, 'ES256', kid: JWT::JWK.new(key).export[:kid])

    encrypt_for_procedure(signed, **encryption)
  end

  def encrypt_for_procedure(payload, alg: KEY_MANAGEMENT, enc: CONTENT_ENCRYPTION)
    JWE.encrypt(payload, JWT::JWK.new(procedure_jwk).verify_key, alg:, enc:)
  end
end

RSpec.configure { |config| config.include FranceConnectStubs }
