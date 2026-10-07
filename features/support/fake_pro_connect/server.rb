require 'cgi'
require 'json'
require 'jwt'
require 'openssl'
require 'securerandom'
require 'uri'
require 'webrick'
require_relative 'identities'

module FakeProConnect
  # The one service provider the fake knows: the administration space, with
  # the two addresses it declares to ProConnect, read off the application's
  # own base URL so that a worktree on shifted ports has nothing to declare.
  Client = Data.define(:id, :secret, :redirect_uri, :post_logout_redirect_uri) do
    def self.console(application_url)
      new(id: 'oots-france-console', secret: 'faux-proconnect-secret-de-la-console',
        redirect_uri: "#{application_url}/admin/proconnect/retour_connexion",
        post_logout_redirect_uri: "#{application_url}/admin/proconnect/retour_deconnexion")
    end
  end

  # ProConnect as a service provider meets it, in Authorization Code Flow: a
  # discovery document, a key set, an authorization page offering the two
  # identities, `/token` in `client_secret_post`, a UserInfo signed as a JWT,
  # and the end of session. In memory, single-use codes, nothing persisted.
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique
  class Server
    SCOPES = %w[openid email].freeze
    AUTHORIZE_PARAMETERS = %w[response_type client_id redirect_uri scope state nonce].freeze
    MINIMUM_RANDOM = 32
    SIGNING_ALGORITHM = 'RS256'.freeze
    LIFETIME = 60

    ROUTES = {
      %w[GET /.well-known/openid-configuration] => :discovery_document, %w[GET /jwks] => :key_set,
      %w[GET /authorize] => :authorize, %w[POST /interaction] => :interaction, %w[POST /token] => :token,
      %w[GET /userinfo] => :userinfo, %w[GET /session/end] => :session_end
    }.freeze

    def initialize(issuer:, application_url:)
      @issuer = issuer
      @client = Client.console(application_url)
      @key = OpenSSL::PKey::RSA.generate(2048)
      @codes = {}
      @access_tokens = {}
      @lock = Mutex.new
    end

    def run(port:)
      server = WEBrick::HTTPServer.new(Port: port, BindAddress: '0.0.0.0',
        Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      server.mount_proc('/') { |request, response| dispatch(request, response) }
      %w[TERM INT].each { |signal| trap(signal) { server.shutdown } }

      server.start
    end

    private

    attr_reader :issuer, :client, :key

    def dispatch(request, response)
      route = ROUTES.fetch([request.request_method, request.path.delete_prefix(URI.parse(issuer).path)], :not_found)

      send(route, request, response)
    rescue StandardError => e
      warn("#{e.class}: #{e.message}")
      refuse(response, e.class.name, e.message, status: 500)
    end

    def discovery_document(_request, response) = json(response, discovery)

    def key_set(_request, response)
      json(response, { keys: [JWT::JWK.new(key).export.merge(use: 'sig', alg: SIGNING_ALGORITHM)] })
    end

    def not_found(_request, response) = refuse(response, 'not_found', 'unknown endpoint', status: 404)

    def discovery
      { issuer:, authorization_endpoint: under('/authorize'), token_endpoint: under('/token'),
        userinfo_endpoint: under('/userinfo'), jwks_uri: under('/jwks'), end_session_endpoint: under('/session/end'),
        response_types_supported: %w[code], grant_types_supported: %w[authorization_code],
        scopes_supported: SCOPES, token_endpoint_auth_methods_supported: %w[client_secret_post],
        id_token_signing_alg_values_supported: [SIGNING_ALGORITHM],
        userinfo_signing_alg_values_supported: [SIGNING_ALGORITHM] }
    end

    # What the real one refuses, refused alike: an unknown client, an address
    # it was not declared, scopes it does not grant, a `state` or a `nonce`
    # under thirty-two characters, and any parameter it does not know —
    # « tout paramètre supplémentaire dans l'URL génèrera une erreur Y000400 ».
    def authorize(request, response)
      asked = request.query
      reason = authorize_refusal(asked)
      return refuse(response, 'invalid_request', reason) if reason

      page(response, authorization_page(asked))
    end

    def authorize_refusal(asked)
      unknown = asked.keys - AUTHORIZE_PARAMETERS
      return "paramètres inconnus : #{unknown.join(', ')}" unless unknown.empty?

      authorize_checks(asked).find { |_reason, holds| !holds }&.first
    end

    def authorize_checks(asked)
      scopes = asked['scope'].to_s.split

      { 'client_id inconnu' => asked['client_id'] == client.id,
        'redirect_uri non déclarée' => asked['redirect_uri'] == client.redirect_uri,
        'response_type autre que code' => asked['response_type'] == 'code',
        'scopes non accordés' => scopes.include?('openid') && (scopes - SCOPES).empty?,
        'state ou nonce de moins de 32 caractères' => random_enough?(asked) }
    end

    def random_enough?(asked) = %w[state nonce].all? { |name| asked[name].to_s.length >= MINIMUM_RANDOM }

    def interaction(request, response)
      asked = request.query
      identity = Identities.find(asked['sub'])
      return refuse(response, 'invalid_request', 'identité inconnue') if identity.nil? || authorize_refusal(asked.except('sub'))

      code = SecureRandom.hex(16)
      @lock.synchronize { @codes[code] = { identity:, nonce: asked['nonce'] } }

      redirect(response, client.redirect_uri, code:, state: asked['state'])
    end

    def token(request, response)
      form = request.query
      return refuse(response, 'invalid_client', 'identifiants du client refusés', status: 401) unless
        form['client_id'] == client.id && form['client_secret'] == client.secret

      grant = redeemed(form)
      return refuse(response, 'invalid_grant', 'code inconnu ou déjà utilisé') if grant.nil?

      json(response, granted(grant))
    end

    # Single use: the code is taken out whatever else the request gets wrong.
    def redeemed(form)
      grant = @lock.synchronize { @codes.delete(form['code']) }

      grant if form['grant_type'] == 'authorization_code' && form['redirect_uri'] == client.redirect_uri
    end

    def granted(grant)
      access_token = SecureRandom.hex(32)
      @lock.synchronize { @access_tokens[access_token] = grant.fetch(:identity) }

      { access_token:, token_type: 'Bearer', expires_in: LIFETIME, scope: SCOPES.join(' '),
        id_token: signed(claims(grant.fetch(:identity)).merge(nonce: grant.fetch(:nonce))) }
    end

    def userinfo(request, response)
      identity = @lock.synchronize { @access_tokens[request['Authorization'].to_s.delete_prefix('Bearer ')] }
      return refuse(response, 'invalid_token', 'access token inconnu', status: 401) if identity.nil?

      response['Content-Type'] = 'application/jwt'
      response.body = signed(claims(identity).merge(email: identity.email, given_name: identity.given_name,
        usual_name: identity.usual_name))
    end

    def session_end(request, response)
      asked = request.query
      return refuse(response, 'invalid_request', 'post_logout_redirect_uri non déclarée') unless
        asked['post_logout_redirect_uri'] == client.post_logout_redirect_uri
      return refuse(response, 'invalid_request', 'state absent') if asked['state'].to_s.empty?

      redirect(response, client.post_logout_redirect_uri, state: asked['state'])
    end

    def claims(identity)
      now = Time.now.to_i

      { iss: issuer, sub: identity.sub, aud: client.id, iat: now, exp: now + LIFETIME }
    end

    def signed(payload) = JWT.encode(payload, key, SIGNING_ALGORITHM, kid: JWT::JWK.new(key).export[:kid])

    def under(path) = "#{issuer}#{path}"

    def authorization_page(asked)
      forms = Identities::ALL.map do |identity|
        hidden = asked.merge('sub' => identity.sub).map do |name, value|
          %(<input type="hidden" name="#{h(name)}" value="#{h(value)}">)
        end
        %(<form method="post" action="#{h(under('/interaction'))}">#{hidden.join}) +
          %(<button type="submit">#{h(identity.email)}</button></form>)
      end

      '<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Faux ProConnect</title></head>' \
        "<body><h1>Faux ProConnect</h1><p>Choisir l'identité de test :</p>#{forms.join}</body></html>"
    end

    def h(value) = CGI.escapeHTML(value.to_s)

    def json(response, payload)
      response['Content-Type'] = 'application/json'
      response.body = JSON.generate(payload)
    end

    def page(response, html)
      response['Content-Type'] = 'text/html; charset=utf-8'
      response.body = html
    end

    def redirect(response, uri, parameters)
      response.status = 302
      response['Location'] = "#{uri}?#{URI.encode_www_form(parameters)}"
    end

    def refuse(response, error, description, status: 400)
      response.status = status
      json(response, { error:, error_description: description })
    end
  end
end

if $PROGRAM_NAME == __FILE__
  # Empty rather than absent is what an `.env.oots` written for a deployment
  # gives: such a deployment declares the real ProConnect, or none, and never
  # starts this service.
  %w[URL_PROCONNECT URL_OOTS_FRANCE].each do |variable|
    next unless ENV.fetch(variable, '').empty?

    abort("#{variable} est vide : le faux ProConnect ne peut pas démarrer. Voir docs/test_e2e.md.")
  end

  issuer = ENV.fetch('URL_PROCONNECT')
  declared = ENV.fetch('PORT_FAUX_PROCONNECT', '')
  port = declared.empty? ? URI.parse(issuer).port : Integer(declared)

  FakeProConnect::Server.new(issuer:, application_url: ENV.fetch('URL_OOTS_FRANCE')).run(port:)
end
