require 'nokogiri'

# The service provider the scenario plays against the fake FranceConnect+ —
# what OOTS-179 will make the demonstration procedure do, proved here before a
# line of it exists.
#
# An HTTP client and not a browser: the `Dockerfile` installs no Chrome and
# nothing wires Cuprite into Cucumber, and three forms are worth a Faraday and
# a Nokogiri rather than a dependency in the image. It reads the forms of the
# three pages and submits them, which is exactly the path a browser walks.
class FranceConnectClient
  # What a procedure asks of a European user: no `profile`, which a scenario
  # adds on its own to see `preferred_username` appear.
  DEFAULT_SCOPE = 'openid given_name family_name birthdate gender birthplace'.freeze

  attr_reader :client_id, :redirect_uri, :page, :state

  def initialize(issuer:, client_id:, client_secret:, redirect_uri:, private_key_jwk:)
    @issuer = issuer
    @client_id = client_id
    @client_secret = client_secret
    @redirect_uri = redirect_uri
    @private_key = JWT::JWK.new(private_key_jwk).signing_key
    @connection = Faraday.new do |builder|
      builder.request(:url_encoded)
      builder.adapter(Faraday.default_adapter)
    end
  end

  # The procedure knows the fake by its discovery document alone: every address
  # below is read from it, and none is built here.
  def discovery = @discovery ||= JSON.parse(discovery_response.body)

  def discovery_response = @discovery_response ||= get(discovery_url)

  def key_set_response = get(discovery.fetch('jwks_uri'))

  def key_set = JWT::JWK::Set.new(JSON.parse(key_set_response.body))

  # `GET` or `POST`, both of which the core accepts on `/authorize`.
  def authorize(http_method: :get, **overrides)
    @state = overrides.fetch(:state, SecureRandom.hex(8))
    endpoint = discovery.fetch('authorization_endpoint')
    parameters = authorize_parameters(overrides)

    @page = http_method == :post ? connection.post(endpoint, parameters) : get(endpoint, parameters)
  end

  def choose_country(code) = @page = submit('country', code)

  def choose_identity(key) = @page = submit('identity', key)

  def confirm = @page = submit('consent', 'yes')

  # The same step submitted a second time, to see an interaction that has been
  # closed refuse what it used to accept.
  def resubmit(name, value) = @page = connection.post(@action, name => value)

  def title = Nokogiri::HTML(page.body).at_css('h1')&.text.to_s

  # What the browser is sent back with, `nil` when it is not sent back at all.
  def returned
    return unless page.status == 302

    URI.decode_www_form(URI.parse(page.headers['Location']).query.to_s).to_h
  end

  def exchange(code, **overrides)
    connection.post(discovery.fetch('token_endpoint'),
      token_parameters(code).merge(client_id: client_id, client_secret: client_secret, **overrides))
  end

  # The credentials in a header and nowhere else: `client_secret_basic` is not
  # among the methods the core accepts, and the fake refuses it too.
  def exchange_with_basic_authentication(code)
    credentials = Base64.strict_encode64("#{client_id}:#{client_secret}")

    connection.post(discovery.fetch('token_endpoint'), token_parameters(code),
      'Authorization' => "Basic #{credentials}")
  end

  def userinfo(access_token)
    get(discovery.fetch('userinfo_endpoint'), {}, 'Authorization' => "Bearer #{access_token}")
  end

  def end_session(parameters) = get(discovery.fetch('end_session_endpoint'), parameters)

  def decrypted(sealed) = JWE.decrypt(sealed, private_key)

  # Only the procedure's private key opens the JWE, and the JWT inside it is
  # signed by a key of the set the fake publishes — read again at each call,
  # which is what a rotation obliges a reader to do.
  def unseal(sealed)
    JWT.decode(decrypted(sealed), nil, true, algorithms: %w[ES256], jwks: key_set).first
  end

  def signing_kid(sealed) = JWT.decode(decrypted(sealed), nil, false).last['kid']

  def published_kids = JSON.parse(key_set_response.body).fetch('keys').map { |key| key.fetch('kid') }

  private

  attr_reader :issuer, :client_secret, :private_key, :connection

  def discovery_url = "#{issuer}/.well-known/openid-configuration"

  def token_parameters(code) = { grant_type: 'authorization_code', code: code, redirect_uri: redirect_uri }

  def get(url, parameters = {}, headers = {}) = connection.get(url, parameters, headers)

  def authorize_parameters(overrides)
    {
      client_id: client_id, response_type: 'code', redirect_uri: redirect_uri, scope: DEFAULT_SCOPE,
      state: state, nonce: SecureRandom.hex(16), acr_values: 'eidas2', idp_hint: 'eidas-bridge',
    }.merge(overrides).compact
  end

  # The form's own action, read off the page: the scenario walks where the fake
  # sends it rather than where the test believes it should go.
  def submit(name, value)
    form = Nokogiri::HTML(page.body).at_css('form')
    raise "Aucun formulaire dans la page « #{title} » : #{page.body}" if form.nil?

    @action = absolute(form['action'])

    connection.post(@action, name => value)
  end

  def absolute(action)
    address = URI.parse(issuer)

    "#{address.scheme}://#{address.host}:#{address.port}#{action}"
  end
end
