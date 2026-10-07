# What an OpenID Connect provider is known by here: its **discovery document**,
# and nothing else. Every endpoint a client calls is read from it, none is built
# by hand — which is what makes a sandbox, a production and a fake of the suite
# a change of configuration rather than a line of code.
#
# Shared by `FranceConnectClient` and `ProConnectClient`, because what it holds
# is a defence and not a convenience: an endpoint the document publishes off the
# configured issuer would carry the `client_secret` and the access token to
# whoever wrote the document, and two copies of that check would drift apart.
#
# The including class names what differs between providers: `instance` (an
# issuer and its credentials), `discovery_error` (the class every refusal is
# raised as), `discovery_scope` (where its messages are translated, under
# `clients.`), `cache_namespace`, and `document(body)`, which parses the
# document and refuses what is not a JSON object.
#
# The document is cached like the code lists are, and for the same reason: it is
# read on every authentication and changes about never.
# https://openid.net/specs/openid-connect-discovery-1_0.html#ProviderConfig
module OpenidDiscovery
  DISCOVERY_PATH = '/.well-known/openid-configuration'.freeze
  CACHE_DURATION = 1.hour

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

  # The configured issuer, once the document has been seen to claim it: what
  # the ID Token is checked against must be what this deployment was told to
  # talk to, never what the answer said of itself.
  def issuer
    announced = discovery.fetch('issuer', nil)
    return configured_issuer if announced.to_s.chomp('/') == configured_issuer

    raise discovery_error, discovery_message(:foreign_issuer, announced:, expected: configured_issuer)
  end

  def jwks_url = endpoint('jwks_uri')

  private

  # An address published by the discovery document, rebuilt on the origin this
  # deployment was configured with: the document says which path to call, never
  # which host to call it on.
  #
  # Both providers publish their five endpoints under the base of the
  # environment, so an address pointing elsewhere is a document that is not the
  # provider's, and following it would carry the `client_secret` and the access
  # token to whoever wrote it.
  # https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-endpoints/
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique
  def endpoint(name)
    published = published_endpoint(name)
    origin = URI.parse(configured_issuer)
    path = shape(name, published, origin)

    under_issuer(name, published, origin, "#{configured_issuer}#{rebuilt(path)}")
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
    base = configured_issuer
    called = origin.dup.tap { |root| root.path = '/' }.merge(URI.parse(address).path).to_s
    return address if address.start_with?(base) && called.start_with?(base)

    refuse_foreign(name, published, origin)
  end

  # `fetch` without a default on purpose: `SEGMENTS` has already refused
  # anything the table does not hold, so a miss here could only mean the two
  # have drifted apart — a defect of this file, which has no business being
  # dressed up as a refusal the provider earned.
  def rebuilt(path) = path.each_char.map { |character| PATH_CHARACTERS.fetch(character) }.join

  def same_origin?(published, origin)
    [published.scheme, published.host, published.port] == [origin.scheme, origin.host, origin.port]
  end

  def refuse_foreign(name, published, origin)
    raise discovery_error, discovery_message(:foreign_endpoint, name:, url: published, expected: origin.host)
  end

  # **The one place an endpoint is taken out of the discovery document**, and the
  # one place its three ways of being unusable are named: absent, unreadable as
  # JSON — `published_discovery` answers for that one — or not an address at
  # all. `issuer` is the only other reader of the document, and it reads a value
  # that is compared to configuration rather than called, with a default rather
  # than a refusal.
  def published_endpoint(name)
    URI.parse(discovery.fetch(name) { refuse_missing(name) }.to_s)
  rescue URI::InvalidURIError => e
    raise discovery_error, discovery_message(:unreadable_endpoint, name:, error: e.message)
  end

  def refuse_missing(name)
    raise discovery_error, discovery_message(:missing_endpoint, name:)
  end

  def discovery = @discovery ||= published_discovery

  # Read from the instance the client was built on, and never from the
  # environment: `Settings` says which providers exist, the caller says which
  # one it is talking to.
  def configured_issuer = instance.issuer

  # Keyed by the issuer it was read from, as `JwksFetcher` keys by the address
  # it fetched: the issuer is a variable of the deployment, and a key that did
  # not name it would serve the document of one provider to a deployment
  # configured on another — the endpoints of the fake to a deployment pointed at
  # the sandbox, refused as foreign by the check above.
  #
  # Parsed **inside** the cache block, and not after it: a body that does not
  # read as JSON — a maintenance page answered with a 200, a truncated
  # response — is then never written, where caching it would serve a passing
  # outage for the whole freshness window. `CodeListClient` keeps an empty
  # answer out of its cache for the same reason.
  def published_discovery
    Rails.cache.fetch("#{cache_namespace}/openid_configuration/#{configured_issuer}", expires_in: CACHE_DURATION) do
      document(get("#{configured_issuer}#{DISCOVERY_PATH}").body)
    end
  rescue JSON::ParserError => e
    raise discovery_error, discovery_message(:unreadable_discovery, error: e.message)
  end

  def discovery_message(key, **) = I18n.t("clients.#{discovery_scope}.#{key}", **)

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
