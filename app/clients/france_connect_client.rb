# FranceConnect+, as the demonstration procedure calls it. The TDD never name
# the portal; chapter 1 §10.1 does not exclude « a national authentication
# service » between the eIDAS node and the Online Procedure Portal, and reading
# FranceConnect+ into that place is this repository's, that section declaring
# itself illustrative and not normative.
#
# It knows the portal by its **discovery document** and by nothing else —
# `OpenidDiscovery` reads every endpoint below from it. That is what makes the
# sandbox, the production and the fake of the end-to-end suite a change of
# configuration: a `FranceConnectInstance`, and no line of code.
#
# Which one it is, is the caller's to say and never this file's to look up: a
# deployment declares several, and the one an identification departed on is the
# one its return, its UserInfo and its sign-out must address.
class FranceConnectClient
  include OpenidDiscovery

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

  def initialize(instance:, connection: nil)
    @instance = instance
    @connection = connection
  end

  delegate :client_id, to: :instance

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
    url = endpoint('token_endpoint')

    answer = motivated(url) do
      post(url, { grant_type: 'authorization_code', code:, redirect_uri:,
                  client_id:, client_secret: instance.client_secret })
    end

    granted(answer.body)
  end

  # A signed then encrypted JWT, not JSON: what comes back is handed to
  # `FranceConnectToken` as it stands.
  def userinfo(access_token)
    url = endpoint('userinfo_endpoint')

    motivated(url) { get(url, {}, 'Authorization' => "Bearer #{access_token}") }.body
  end

  def end_session_url(id_token_hint:, state:)
    with_query(endpoint('end_session_endpoint'), {
      id_token_hint:, state:, post_logout_redirect_uri:,
    })
  end

  private

  # Read and never published: it carries the `client_secret`, and what this
  # client legitimately exposes of it — the `client_id`, the issuer once the
  # document has claimed it — it exposes one value at a time.
  attr_reader :instance

  # The two endpoints that motivate a refusal, relayed in the portal's own words
  # rather than in the message the HTTP client raises with, which names only the
  # verb, the status and the address. What the portal did not motivate is left to
  # that message.
  def motivated(url)
    yield
  rescue Faraday::Error => e
    reason = FranceConnectRefusal.new(e, url).reason
    raise FranceConnectError, reason if reason

    raise
  end

  def granted(body)
    tokens = FranceConnectAnswer.object(JSON.parse(body), :grant)
    missing = GRANTED.reject { |name| tokens[name].is_a?(String) && !tokens[name].empty? }
    return tokens if missing.empty?

    raise FranceConnectError,
      I18n.t('clients.france_connect_client.incomplete_grant', names: missing.join(', '))
  rescue JSON::ParserError => e
    raise FranceConnectError, I18n.t('clients.france_connect_client.unreadable_grant', error: e.message)
  end

  def url_for(path) = "#{Settings.oots_france_url}#{path}"

  def discovery_error = FranceConnectError

  def discovery_scope = 'france_connect_client'

  def cache_namespace = 'france_connect'

  def document(body) = FranceConnectAnswer.object(JSON.parse(body), :discovery)
end
