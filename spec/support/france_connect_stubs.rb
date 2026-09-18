# FranceConnect+ as the demonstration procedure meets it: a discovery document,
# a JWKS, and tokens signed then encrypted for the key the procedure publishes.
#
# The endpoints are named from the discovery document alone, exactly as the
# client reads them — a double that answered a path the client built itself
# would prove the client right about a path nothing publishes.
module FranceConnectStubs
  # Pinned here and forced onto `Settings`, rather than read from the
  # environment: `.env.oots` reaches the container through `env_file` and would
  # otherwise decide what these examples assert — how many cards the home page
  # offers as much as where the flow departs.
  PROCEDURE_URL = 'http://oots.test'.freeze
  CLIENT_ID = 'oots-france-demarche'.freeze
  CLIENT_SECRET = 'secret-de-la-demarche'.freeze

  ISSUER = 'http://franceconnect.test/api/v2'.freeze

  # The second FranceConnect+ a deployment may declare, distinct from the first
  # in all three values: an example proving a departure reached one and not the
  # other proves nothing if the two share an address or a credential.
  REAL_ISSUER = 'http://vrai-franceconnect.test/api/v2'.freeze
  REAL_CLIENT_ID = 'oots-france-demarche-au-vrai'.freeze
  REAL_CLIENT_SECRET = 'secret-de-la-demarche-au-vrai'.freeze

  # The five paths FranceConnect+ publishes under its base, in one place: the
  # constants below and the document the doubles serve are both built from this,
  # so a renamed route cannot move on one side and stay on the other.
  # https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-endpoints/
  PATHS = { authorization_endpoint: '/authorize', token_endpoint: '/token',
            userinfo_endpoint: '/userinfo', jwks_uri: '/jwks',
            end_session_endpoint: '/session/end' }.freeze

  DISCOVERY_URL = "#{ISSUER}#{FranceConnectClient::DISCOVERY_PATH}".freeze
  AUTHORIZATION_ENDPOINT = "#{ISSUER}#{PATHS[:authorization_endpoint]}".freeze
  TOKEN_ENDPOINT = "#{ISSUER}#{PATHS[:token_endpoint]}".freeze
  USERINFO_ENDPOINT = "#{ISSUER}#{PATHS[:userinfo_endpoint]}".freeze
  JWKS_URL = "#{ISSUER}#{PATHS[:jwks_uri]}".freeze
  END_SESSION_ENDPOINT = "#{ISSUER}#{PATHS[:end_session_endpoint]}".freeze

  # The three addresses of the other double an example asserts on: where a
  # departure lands, where its discovery is read, where a sign-out goes.
  REAL_DISCOVERY_URL = "#{REAL_ISSUER}#{FranceConnectClient::DISCOVERY_PATH}".freeze
  REAL_AUTHORIZATION_ENDPOINT = "#{REAL_ISSUER}#{PATHS[:authorization_endpoint]}".freeze
  REAL_END_SESSION_ENDPOINT = "#{REAL_ISSUER}#{PATHS[:end_session_endpoint]}".freeze

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

  # What a deployment declares, as `Settings` answers for it. Accumulated across
  # calls, in the order `Settings::FRANCE_CONNECT` writes — which is the order
  # the home page reads — so that an example declaring the second keeps the
  # first, and both cards appear where they would on a deployment.
  def declare_france_connect(*instances)
    @declared_france_connect = (@declared_france_connect || {}).merge(instances.index_by(&:name))
    declared = Settings::FRANCE_CONNECT.keys.filter_map { |name| @declared_france_connect[name] }

    allow(Settings).to receive(:france_connect_instances).and_return(declared)
    allow(Settings).to receive(:france_connect_instance) { |name| @declared_france_connect[name] }

    instances.last
  end

  # The other way a deployment changes: one it declared, it declares no more.
  # What a session written under the earlier configuration meets on its return.
  def undeclare_france_connect(name)
    @declared_france_connect = (@declared_france_connect || {}).except(name)

    declare_france_connect
  end

  def fake_france_connect(issuer: ISSUER)
    FranceConnectInstance.new(name: 'fake', issuer:, client_id: CLIENT_ID, client_secret: CLIENT_SECRET)
  end

  def real_france_connect(issuer: REAL_ISSUER)
    FranceConnectInstance.new(name: 'real', issuer:, client_id: REAL_CLIENT_ID,
      client_secret: REAL_CLIENT_SECRET)
  end

  # `issuer:` is what a scenario played in a browser moves: the authorization
  # endpoint has to be somewhere the browser can reach, and
  # `FranceConnectClient#endpoint` rebuilds every address on the origin of the
  # configured issuer. Everything else is the same double — hence the parameter
  # rather than a second copy of it.
  def stub_france_connect(userinfo: DANISH_USERINFO, issuer: ISSUER, instance: nil)
    instance = declare_france_connect(instance || fake_france_connect(issuer:))

    allow(Settings).to receive_messages(
      france_connect_private_key_jwk: procedure_jwk, oots_france_url: PROCEDURE_URL,
    )
    stub_france_connect_endpoints(instance.issuer, userinfo)

    instance
  end

  def stub_france_connect_endpoints(issuer, userinfo)
    stub_request(:get, "#{issuer}#{FranceConnectClient::DISCOVERY_PATH}")
      .to_return(body: discovery_document(issuer).to_json)
    stub_request(:get, "#{issuer}#{PATHS[:jwks_uri]}").to_return(body: france_connect_key_set.to_json)
    stub_france_connect_userinfo(userinfo, issuer:)
  end

  # The other one, doubled exactly as the fake is: the two differ by an issuer
  # and two credentials, which is the whole of what this ticket makes vary.
  def stub_real_france_connect(userinfo: DANISH_USERINFO, issuer: REAL_ISSUER)
    stub_france_connect(userinfo:, instance: real_france_connect(issuer:))
  end

  def stub_france_connect_userinfo(claims, issuer: ISSUER)
    stub_request(:get, "#{issuer}#{PATHS[:userinfo_endpoint]}")
      .to_return(body: sealed_for_procedure(claims), headers: { 'Content-Type' => 'application/jwt' })
  end

  def stub_france_connect_tokens(id_token_claims, access_token: 'un-jeton-d-acces', issuer: ISSUER)
    stub_request(:post, "#{issuer}#{PATHS[:token_endpoint]}").to_return(
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
  def identify_demo_user(userinfo: DANISH_USERINFO, instance: nil, **id_token)
    instance = stub_france_connect(userinfo:, instance:)
    departure = depart_from_demo_home(instance)

    stub_france_connect_tokens(granted_id_token(instance, departure, id_token), issuer: instance.issuer)

    get '/demo/franceconnect/retour_connexion', params: { code: 'un-code', state: departure.fetch('state') }
  end

  # The card of one FranceConnect+, submitted as the home page submits it — the
  # name travels in the body, and nothing else says where the flow departs — and
  # what the departure was written with, read off the address the browser is
  # sent to rather than out of the session.
  def depart_from_demo_home(instance)
    post admin_demo_identification_path, params: { france_connect: instance.name }

    URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h
  end

  def granted_id_token(instance, departure, overrides)
    france_connect_id_token_claims(iss: instance.issuer, aud: instance.client_id,
      nonce: departure.fetch('nonce'), **overrides)
  end

  # The document as the portal publishes it, every endpoint built on `PATHS`:
  # the client reads its addresses from here and nowhere else.
  def discovery_document(issuer = ISSUER)
    { issuer: }.merge(PATHS.transform_values { |path| "#{issuer}#{path}" })
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
