require 'uri'
require 'webrick'
require_relative 'authentication'
require_relative 'authorize_request'
require_relative 'clients'
require_relative 'delivery'
require_relative 'responses'
require_relative 'store'
require_relative 'tokens'

module FakeFranceConnect
  # What every endpoint needs and none owns.
  Configuration = Data.define(:issuer, :clients, :store, :tokens) do
    def base_path = URI.parse(issuer).path
  end

  # FranceConnect+ and, behind it, the eIDAS bridge and a member state's node,
  # as a service provider sees them. Run as a process of its own — see
  # `features/support/fake_france_connect.rb` for why.
  class Server
    include Responses

    # Outside the issuer, so that nothing of it can be taken for an endpoint of
    # the specification: what the scenario drives from the outside — a key
    # rotation, an authorization code aged past its thirty seconds — lives here.
    # `Runner` builds its calls from this same constant.
    COMMANDS = '/commands'.freeze

    def initialize(issuer:, procedure_url:)
      @configuration = Configuration.new(
        issuer: issuer, clients: Clients.all(procedure_url), store: Store.new,
        tokens: Tokens.new(procedure_key_set_url: "#{procedure_url}/demo/franceconnect/cles_publiques"),
      )
      @authentication = Authentication.new(configuration)
      @delivery = Delivery.new(configuration)
    end

    def run
      server = WEBrick::HTTPServer.new(Port: URI.parse(configuration.issuer).port, BindAddress: '0.0.0.0',
        Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      server.mount_proc('/') { |request, response| dispatch(request, response) }
      %w[TERM INT].each { |signal| trap(signal) { server.shutdown } }

      server.start
    end

    private

    attr_reader :configuration, :authentication, :delivery

    def dispatch(request, response)
      path = request.path

      if path.start_with?(COMMANDS)
        command(request, response, path.delete_prefix(COMMANDS))
      else
        endpoint(request, response, path.delete_prefix(configuration.base_path))
      end
    rescue StandardError => e
      failed(response, e)
    end

    # Broad on purpose: a failure of the fake has to reach the scenario, which
    # reads bodies — WEBrick would otherwise answer its own 500 page and take
    # the message with it, and « ECDH-ES is not handled by the gem » is exactly
    # the sort of message that must not be lost.
    def failed(response, error)
      warn("#{error.class}: #{error.message}")
      page(response, Pages.error(error.class.name, error.message), status: 500)
    end

    def endpoint(request, response, path)
      case [request.request_method, path]
      when %w[GET /.well-known/openid-configuration] then discovery(response)
      when %w[GET /jwks] then key_set(response)
      when %w[GET /authorize], %w[POST /authorize] then authentication.authorize(request, response)
      when %w[POST /token] then delivery.token(request, response)
      when %w[GET /userinfo] then delivery.userinfo(request, response)
      when %w[GET /session/end] then delivery.session_end(request, response)
      else interaction(request, response, path)
      end
    end

    def interaction(request, response, path)
      return not_found(response) unless request.request_method == 'POST' &&
                                        path.start_with?(Authentication::INTERACTION)

      uid, name = path.delete_prefix(Authentication::INTERACTION).split('/')

      authentication.advance(request, response, uid, name)
    end

    def command(request, response, name)
      return not_found(response) unless request.request_method == 'POST'

      case name
      when '/rotate-signing-key' then configuration.tokens.rotate
      when '/age-authorization-codes' then configuration.store.age_codes(seconds(request))
      when '/age-access-tokens' then configuration.store.age_access_tokens(seconds(request))
      else return not_found(response)
      end

      json(response, done: name)
    end

    # The procedure knows FranceConnect+ by this document and by nothing else:
    # swapping the fake for the sandbox is a change of address, of `client_id`
    # and of `client_secret`, and of no line of code.
    def discovery(response)
      cacheable_json(response, {
        issuer: configuration.issuer,
        authorization_endpoint: under('/authorize'), token_endpoint: under('/token'),
        userinfo_endpoint: under('/userinfo'), jwks_uri: under('/jwks'),
        end_session_endpoint: under('/session/end'),
        response_types_supported: %w[code], grant_types_supported: %w[authorization_code],
        subject_types_supported: %w[pairwise], scopes_supported: Clients::SCOPES,
        acr_values_supported: AuthorizeRequest::ACR_VALUES,
        token_endpoint_auth_methods_supported: %w[client_secret_post],
        id_token_signing_alg_values_supported: [Tokens::SIGNING_ALGORITHM],
        id_token_encryption_alg_values_supported: Tokens::KEY_MANAGEMENT_ALGORITHMS,
        id_token_encryption_enc_values_supported: [Tokens::ENCRYPTION_METHOD],
        userinfo_signing_alg_values_supported: [Tokens::SIGNING_ALGORITHM],
        userinfo_encryption_alg_values_supported: Tokens::KEY_MANAGEMENT_ALGORITHMS,
        userinfo_encryption_enc_values_supported: [Tokens::ENCRYPTION_METHOD],
      }, 'application/json')
    end

    def key_set(response)
      cacheable_json(response, configuration.tokens.key_set, 'application/jwk-set+json')
    end

    def seconds(request) = request.query['seconds'].to_i

    def under(path) = "#{configuration.issuer}#{path}"
  end
end

if $PROGRAM_NAME == __FILE__
  # An empty issuer, and not an absent one, is what an `.env.oots` written for a
  # deployment gives: `env_file` posts the variable all the same. Without this,
  # `URI.parse('').port` is nil, WEBrick binds 80, and the stack answers a
  # discovery document nobody asked for on a port nobody named.
  %w[URL_FAUX_FRANCE_CONNECT URL_OOTS_FRANCE].each do |variable|
    next unless ENV.fetch(variable, '').empty?

    abort("#{variable} est vide : le faux FranceConnect+ ne peut pas démarrer. " \
          'Voir docs/test_e2e.md — un déploiement ne lance pas ce service.')
  end

  FakeFranceConnect::Server.new(
    issuer: ENV.fetch('URL_FAUX_FRANCE_CONNECT'), procedure_url: ENV.fetch('URL_OOTS_FRANCE'),
  ).run
end
