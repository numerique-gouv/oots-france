# FranceConnect+, as the demonstration procedure calls it: the European flow of
# chapter 1 §10.1, whose « national authentication service » it plays for France.
#
# It knows the portal by its **discovery document** and by nothing else — every
# endpoint below is read from it, none is built here. That is what makes the
# sandbox, the production and the fake of the end-to-end suite a change of
# environment: an issuer and two credentials, and no line of code.
#
# The document is cached like the code lists are, and for the same reason: it is
# read on every authentication and changes about never.
class FranceConnectClient
  DISCOVERY_PATH = '/.well-known/openid-configuration'.freeze
  CACHE_DURATION = 1.hour

  # `eidas2` and not `eidas3`: the parameter is a floor, so asking for the
  # substantial level admits a user authenticated at either, where asking for
  # the high one would turn away a substantial identity the specification
  # accepts. `eidas1` is not a value FranceConnect+ knows.
  # https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-eidas-acr/
  REQUESTED_ACR = 'eidas2'.freeze

  # Straight to the country page of the eIDAS bridge, without the mire on which
  # French identity providers are chosen.
  # https://docs.partenaires.franceconnect.gouv.fr/fs/passerelle-eidas/technique-eidas-authorize/
  IDP_HINT = 'eidas-bridge'.freeze

  # The mandatory attributes of the minimum data set, and the two optional ones
  # chapter 2.1 §2.4 lets the requester carry. No `profile`, which would add a
  # `preferred_username` nothing here reads.
  SCOPES = 'openid given_name family_name birthdate gender birthplace'.freeze

  # `amr` is not covered by any scope: it is asked for as an essential claim,
  # which is the mechanism OpenID Connect provides and the one the portal leaves
  # enabled. It is what says a European identity came through the bridge.
  ESSENTIAL_CLAIMS = { id_token: { amr: { essential: true } } }.to_json.freeze

  def initialize(connection: nil)
    @connection = connection
  end

  def issuer = discovery.fetch('issuer')

  def jwks_url = discovery.fetch('jwks_uri')

  def client_id = Settings.france_connect_credentials.fetch(:id)

  # Never derived from the request: FranceConnect+ refuses an address it was not
  # declared, and the path is the one `config/routes.rb` publishes.
  def redirect_uri = url_for(Rails.application.routes.url_helpers.demo_franceconnect_retour_connexion_path)

  def post_logout_redirect_uri
    url_for(Rails.application.routes.url_helpers.demo_franceconnect_retour_deconnexion_path)
  end

  def authorization_url(state:, nonce:)
    with_query(discovery.fetch('authorization_endpoint'), {
      client_id:, response_type: 'code', redirect_uri:, scope: SCOPES, state:, nonce:,
      acr_values: REQUESTED_ACR, claims: ESSENTIAL_CLAIMS, idp_hint: IDP_HINT,
    })
  end

  # `client_secret_post`: the credentials travel in the body, FranceConnect+
  # accepting no `Authorization: Basic` on this endpoint.
  def exchange(code)
    credentials = Settings.france_connect_credentials

    JSON.parse(post(discovery.fetch('token_endpoint'), {
      grant_type: 'authorization_code', code:, redirect_uri:,
      client_id: credentials.fetch(:id), client_secret: credentials.fetch(:secret),
    }).body)
  end

  # A signed then encrypted JWT, not JSON: what comes back is handed to
  # `FranceConnectToken` as it stands.
  def userinfo(access_token)
    get(discovery.fetch('userinfo_endpoint'), {}, 'Authorization' => "Bearer #{access_token}").body
  end

  def end_session_url(id_token_hint:, state:)
    with_query(discovery.fetch('end_session_endpoint'), {
      id_token_hint:, state:, post_logout_redirect_uri:,
    })
  end

  private

  def url_for(path) = "#{Settings.oots_france_url}#{path}"

  def discovery = @discovery ||= JSON.parse(published_discovery)

  def published_discovery
    Rails.cache.fetch('france_connect/discovery', expires_in: CACHE_DURATION) do
      get("#{Settings.france_connect_issuer}#{DISCOVERY_PATH}").body
    end
  end

  def with_query(endpoint, parameters)
    address = URI.parse(endpoint)
    address.query = URI.encode_www_form(parameters)

    address.to_s
  end

  def get(url, parameters = {}, headers = {}) = connection.get(url, parameters, headers)

  def post(url, parameters) = connection.post(url, parameters)

  def connection
    @connection ||= Faraday.new do |builder|
      builder.request(:url_encoded)
      builder.response(:raise_error)
      builder.adapter(Faraday.default_adapter)
    end
  end
end
