# FranceConnect+, as the demonstration procedure calls it. The TDD never name
# the portal; chapter 1 §10.1 does not exclude « a national authentication
# service » between the eIDAS node and the Online Procedure Portal, and reading
# FranceConnect+ into that place is this repository's, that section declaring
# itself illustrative and not normative.
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

  # What `/token` must have answered for the exchange to have happened, checked
  # where it arrives. A caller reaching for `id_token` in a hash that has none
  # would raise a `KeyError` far from here, which nothing could name — the
  # repository translates a correspondent's malformed answer at the client, as
  # `BeneficiaryToken` and `CommonServicesSignature` both do.
  GRANTED = %w[access_token id_token].freeze

  # `amr` is not covered by any scope: it is asked for as an essential claim,
  # which is the mechanism OpenID Connect provides and the one the portal leaves
  # enabled. It is what says a European identity came through the bridge.
  ESSENTIAL_CLAIMS = { id_token: { amr: { essential: true } } }.to_json.freeze

  # What is left of a published address once the base is taken off it: plain
  # segments and nothing else. The negative lookahead is the whole point of the
  # expression — `[A-Za-z0-9._~-]+` matches `..` as happily as `authorize`, and
  # a document publishing `<issuer>/../../elsewhere` would otherwise pass every
  # check here and be normalised out of the base by the HTTP client, carrying
  # the `client_secret` and the access token to a path nobody chose.
  SEGMENTS = %r{\A(?:/(?!\.{1,2}(?:/|\z))[A-Za-z0-9._~-]+)*/?\z}

  # The characters `SEGMENTS` admits, each standing for itself. The path is
  # **rebuilt** from this table rather than copied out of the document: the
  # address handed to an HTTP call is then made of characters this file holds,
  # and the document only chooses which ones, in which order. Same path, same
  # refusals — what changes is where the string comes from, which is what a
  # reader of this code, and a taint analysis, can both check.
  PATH_CHARACTERS = [*'a'..'z', *'A'..'Z', *'0'..'9', '/', '.', '_', '~', '-'].index_by(&:itself).freeze

  def initialize(connection: nil)
    @connection = connection
  end

  # The configured issuer, once the document has been seen to claim it: what
  # the ID Token is checked against must be what this deployment was told to
  # talk to, never what the answer said of itself.
  def issuer
    announced = discovery.fetch('issuer', nil)
    return Settings.france_connect_issuer if announced.to_s.chomp('/') == Settings.france_connect_issuer

    raise FranceConnectError,
      I18n.t('clients.france_connect_client.foreign_issuer', announced:, expected: Settings.france_connect_issuer)
  end

  def jwks_url = endpoint('jwks_uri')

  def client_id = Settings.france_connect_credentials.fetch(:id)

  # Never derived from the request: FranceConnect+ refuses an address it was not
  # declared, and the path is the one `config/routes.rb` publishes.
  def redirect_uri = url_for(Rails.application.routes.url_helpers.demo_franceconnect_retour_connexion_path)

  def post_logout_redirect_uri
    url_for(Rails.application.routes.url_helpers.demo_franceconnect_retour_deconnexion_path)
  end

  def authorization_url(state:, nonce:)
    with_query(endpoint('authorization_endpoint'), {
      client_id:, response_type: 'code', redirect_uri:, scope: SCOPES, state:, nonce:,
      acr_values: REQUESTED_ACR, claims: ESSENTIAL_CLAIMS, idp_hint: IDP_HINT,
    })
  end

  # `client_secret_post`: the credentials travel in the body, FranceConnect+
  # accepting no `Authorization: Basic` on this endpoint.
  def exchange(code)
    credentials = Settings.france_connect_credentials

    granted(post(endpoint('token_endpoint'), {
      grant_type: 'authorization_code', code:, redirect_uri:,
      client_id: credentials.fetch(:id), client_secret: credentials.fetch(:secret),
    }).body)
  end

  # A signed then encrypted JWT, not JSON: what comes back is handed to
  # `FranceConnectToken` as it stands.
  def userinfo(access_token)
    get(endpoint('userinfo_endpoint'), {}, 'Authorization' => "Bearer #{access_token}").body
  end

  def end_session_url(id_token_hint:, state:)
    with_query(endpoint('end_session_endpoint'), {
      id_token_hint:, state:, post_logout_redirect_uri:,
    })
  end

  private

  def granted(body)
    tokens = FranceConnectAnswer.object(JSON.parse(body), :grant)
    missing = GRANTED.reject { |name| tokens[name].is_a?(String) && !tokens[name].empty? }
    return tokens if missing.empty?

    raise FranceConnectError,
      I18n.t('clients.france_connect_client.incomplete_grant', names: missing.join(', '))
  rescue JSON::ParserError => e
    raise FranceConnectError, I18n.t('clients.france_connect_client.unreadable_grant', error: e.message)
  end

  # An address published by the discovery document, rebuilt on the origin this
  # deployment was configured with: the document says which path to call, never
  # which host to call it on.
  #
  # FranceConnect+ publishes all five under the base of the environment —
  # « Les chemins sont `authorize`, `token`, `userinfo`, `session/end` et `jwks`
  # sous cette base » — so an address pointing elsewhere is a document that is
  # not the portal's, and following it would carry the `client_secret` and the
  # access token to whoever wrote it.
  # https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-endpoints/
  def endpoint(name)
    published = published_endpoint(name)
    origin = URI.parse(Settings.france_connect_issuer)
    path = shape(name, published, origin)

    under_issuer(name, published, origin, "#{Settings.france_connect_issuer}#{rebuilt(path)}")
  end

  # What the document publishes under the base, once the base is taken off it:
  # refused here if it is not the origin this deployment was configured with, or
  # if it is not made of plain segments.
  def shape(name, published, origin)
    path = published.path.to_s.delete_prefix(origin.path.to_s)
    return path if same_origin?(published, origin) && SEGMENTS.match?(path)

    refuse_foreign(name, published, origin)
  end

  # The last word, said of the address the call will actually receive and not of
  # anything it was derived from: it must start with the base this deployment
  # was configured with, and still start with it once the dot segments are
  # removed — which is what an HTTP client does before opening the connection.
  # Redundant with the lookahead of `SEGMENTS` on purpose: one of the two is an
  # expression that can be got subtly wrong, the other asks the question the
  # attacker actually asks.
  # https://datatracker.ietf.org/doc/html/rfc3986#section-5.2
  def under_issuer(name, published, origin, address)
    base = Settings.france_connect_issuer
    called = origin.dup.tap { |root| root.path = '/' }.merge(URI.parse(address).path).to_s
    return address if address.start_with?(base) && called.start_with?(base)

    refuse_foreign(name, published, origin)
  end

  # `fetch` without a default on purpose: `SEGMENTS` has already refused
  # anything the table does not hold, so a miss here could only mean the two
  # have drifted apart — a defect of this file, which has no business being
  # dressed up as a refusal the portal earned.
  def rebuilt(path) = path.each_char.map { |character| PATH_CHARACTERS.fetch(character) }.join

  def same_origin?(published, origin)
    [published.scheme, published.host, published.port] == [origin.scheme, origin.host, origin.port]
  end

  def refuse_foreign(name, published, origin)
    raise FranceConnectError,
      I18n.t('clients.france_connect_client.foreign_endpoint', name:, url: published, expected: origin.host)
  end

  # **The one place an endpoint is taken out of the discovery document**, and the
  # one place its three ways of being unusable are named: absent, unreadable as
  # JSON — `published_discovery` answers for that one — or not an address at
  # all. `issuer` is the only other reader of the document, and it reads a value
  # that is compared to configuration rather than called, with a default rather
  # than a refusal. A correspondent's malformed answer is translated where it
  # arrives, as `BeneficiaryToken` and `CommonServicesSignature` both do.
  def published_endpoint(name)
    URI.parse(discovery.fetch(name) { refuse_missing(name) }.to_s)
  rescue URI::InvalidURIError => e
    raise FranceConnectError,
      I18n.t('clients.france_connect_client.unreadable_endpoint', name:, error: e.message)
  end

  def refuse_missing(name)
    raise FranceConnectError, I18n.t('clients.france_connect_client.missing_endpoint', name:)
  end

  def url_for(path) = "#{Settings.oots_france_url}#{path}"

  def discovery = @discovery ||= published_discovery

  # Parsed **inside** the cache block, and not after it: a body that does not
  # read as JSON — a maintenance page answered with a 200, a truncated
  # response — is then never written, where caching it would serve a passing
  # outage for the whole freshness window and turn every identification and
  # every sign-out of the next hour into the same failure. `CodeListClient`
  # keeps an empty answer out of its cache for the same reason.
  def published_discovery
    Rails.cache.fetch('france_connect/openid_configuration', expires_in: CACHE_DURATION) do
      document(get("#{Settings.france_connect_issuer}#{DISCOVERY_PATH}").body)
    end
  rescue JSON::ParserError => e
    raise FranceConnectError, I18n.t('clients.france_connect_client.unreadable_discovery', error: e.message)
  end

  def document(body) = FranceConnectAnswer.object(JSON.parse(body), :discovery)

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
