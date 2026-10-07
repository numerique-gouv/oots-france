# ProConnect as the administration space meets it: a discovery document, a
# JWKS, an ID Token signed in RS256 and a UserInfo response, as a JWT or as
# JSON. The endpoints are named from the discovery document alone, as the
# client reads them.
module ProConnectStubs
  # Pinned here and forced onto `Settings`, rather than read from the
  # environment: `.env.oots` reaches the container and would otherwise decide
  # where the flow departs. The base URL is `FranceConnectStubs`' own, so that
  # an example signing in then identifying a user sees one deployment.
  CONSOLE_URL = 'http://oots.test'.freeze
  ISSUER = 'http://proconnect.test/api/v2'.freeze
  CLIENT_ID = 'oots-france-console'.freeze
  CLIENT_SECRET = 'secret-de-la-console'.freeze

  # The five paths ProConnect publishes under its base.
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique
  PATHS = { authorization_endpoint: '/authorize', token_endpoint: '/token',
            userinfo_endpoint: '/userinfo', jwks_uri: '/jwks',
            end_session_endpoint: '/session/end' }.freeze

  AUTHORIZATION_ENDPOINT = "#{ISSUER}#{PATHS[:authorization_endpoint]}".freeze
  TOKEN_ENDPOINT = "#{ISSUER}#{PATHS[:token_endpoint]}".freeze
  END_SESSION_ENDPOINT = "#{ISSUER}#{PATHS[:end_session_endpoint]}".freeze

  AGENT_EMAIL = 'camille.agent@numerique.gouv.fr'.freeze
  AGENT_SUB = 'un-agent-identifie-par-proconnect'.freeze

  def pro_connect_signing_key = @pro_connect_signing_key ||= OpenSSL::PKey::RSA.generate(2048)

  def pro_connect_instance(issuer: ISSUER)
    ProConnectInstance.new(issuer:, client_id: CLIENT_ID, client_secret: CLIENT_SECRET)
  end

  # What a deployment declares, as `Settings` answers for it, and ProConnect's
  # endpoints doubled — the token excepted, which is built at the return from
  # the `nonce` the departure drew.
  def stub_pro_connect(email: AGENT_EMAIL, issuer: ISSUER)
    instance = pro_connect_instance(issuer:)
    allow(Settings).to receive_messages(proconnect_instance: instance, oots_france_url: CONSOLE_URL)

    stub_request(:get, "#{issuer}#{ProConnectClient::DISCOVERY_PATH}")
      .to_return(body: pro_connect_discovery(issuer).to_json)
    stub_request(:get, "#{issuer}#{PATHS[:jwks_uri]}")
      .to_return(body: { keys: [JWT::JWK.new(pro_connect_signing_key).export] }.to_json)
    stub_pro_connect_userinfo({ 'sub' => AGENT_SUB, 'email' => email }, issuer:)

    instance
  end

  # A deployment that declares no ProConnect.
  def undeclare_pro_connect = allow(Settings).to receive(:proconnect_instance).and_return(nil)

  def stub_pro_connect_userinfo(claims, issuer: ISSUER, form: :jwt)
    body, type = form == :jwt ? [signed_by_pro_connect(claims), 'application/jwt'] : [claims.to_json, 'application/json']

    stub_request(:get, "#{issuer}#{PATHS[:userinfo_endpoint]}").to_return(body:, headers: { 'Content-Type' => type })
  end

  def stub_pro_connect_tokens(id_token, issuer: ISSUER)
    stub_request(:post, "#{issuer}#{PATHS[:token_endpoint]}").to_return(
      body: { access_token: 'un-jeton-d-acces', token_type: 'Bearer', expires_in: 60, id_token: }.to_json,
      headers: { 'Content-Type' => 'application/json' },
    )
  end

  # The claims of an ID Token the console would accept, which each example then
  # spoils in the one way it is about.
  def pro_connect_id_token_claims(**overrides)
    now = Time.current.to_i

    { 'iss' => ISSUER, 'sub' => AGENT_SUB, 'aud' => CLIENT_ID, 'iat' => now, 'exp' => now + 60,
      'nonce' => 'le-nonce-de-depart' }.merge(overrides.stringify_keys)
  end

  def signed_by_pro_connect(claims, key: pro_connect_signing_key, algorithm: 'RS256')
    return JWT.encode(claims, key, algorithm) if algorithm.start_with?('HS')

    JWT.encode(claims, key, algorithm, kid: JWT::JWK.new(key).export[:kid])
  end

  def pro_connect_discovery(issuer = ISSUER)
    { issuer: }.merge(PATHS.transform_values { |path| "#{issuer}#{path}" })
  end

  # The departure as the button makes it, and what it was written with, read
  # off the address the browser is sent to rather than out of the session.
  #
  # Through the application's own helpers: once a request has reached the jobs
  # dashboard, the spec's are resolved against the engine's mount point.
  def depart_for_pro_connect
    post Rails.application.routes.url_helpers.admin_session_path

    URI.decode_www_form(URI.parse(response.headers['Location']).query).to_h
  end

  # The whole sign-in as a request spec walks it: the departure, then the return
  # carrying a code and the departure's `state`, the ID Token granted for its
  # `nonce`. `id_token` spoils the claims; `state` the return.
  def return_from_pro_connect(email: AGENT_EMAIL, state: nil, **id_token)
    stub_pro_connect(email:)
    departure = depart_for_pro_connect
    stub_pro_connect_tokens(signed_by_pro_connect(pro_connect_id_token_claims(nonce: departure.fetch('nonce'),
      **id_token)))

    get Rails.application.routes.url_helpers.admin_pro_connect_retour_connexion_path,
      params: { code: 'un-code', state: state || departure.fetch('state') }
  end
end
