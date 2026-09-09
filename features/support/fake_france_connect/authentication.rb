require_relative 'authorize_request'
require_relative 'identities'
require_relative 'pages'
require_relative 'responses'

module FakeFranceConnect
  # `/authorize` and the three pages that follow it: the country, an identity
  # of that country, the consent. No mire in between — the fake is reached with
  # `idp_hint=eidas-bridge` and plays the European path alone.
  class Authentication
    include Responses

    # The path the three pages post to, declared here because this class builds
    # it and `Server` only routes it: one spelling, one owner.
    INTERACTION = '/interaction/'.freeze

    def initialize(configuration)
      @configuration = configuration
    end

    def authorize(request, response)
      demand = AuthorizeRequest.new(request.query.transform_values(&:to_s), configuration.clients)
      return refuse(response, demand) if demand.refusal

      uid = configuration.store.open_interaction(demand: demand)
      page(response, Pages.countries(step(uid, 'country'), Identities.countries))
    end

    # `prompt` changes nothing here on purpose: the core forces
    # `prompt=login consent`, so every call reauthenticates.
    def advance(request, response, uid, name)
      interaction = configuration.store.interaction(uid)
      return error_page(response) if interaction.nil?

      case name
      when 'country' then choose_country(response, uid, request.query['country'].to_s)
      when 'identity' then choose_identity(response, uid, interaction, request.query['identity'].to_s)
      when 'consent' then consent(response, uid, interaction)
      else not_found(response)
      end
    end

    private

    attr_reader :configuration

    def step(uid, name) = "#{configuration.base_path}#{INTERACTION}#{uid}/#{name}"

    def refuse(response, demand)
      refusal = demand.refusal
      return error_page(response, refusal.error, refusal.description) if refusal.page?

      redirect(response, demand.redirect_uri, error: refusal.error, error_description: refusal.description,
        state: demand.state, iss: configuration.issuer)
    end

    def choose_country(response, uid, code)
      identities = Identities.of_country(code)
      return error_page(response, 'invalid_country', "no test identity for #{code}") if identities.empty?

      page(response, Pages.identities(step(uid, 'identity'), identities))
    end

    # The level served is the identity's, never the one asked for; an identity
    # below what the service provider demanded is refused outright. The core
    # refuses it too, but by an HTTP 500 whose message says nothing of the
    # cause; `docs/test_e2e.md` says why the fake answers a plain 400 instead.
    # back/libs/core/src/exceptions/core-low-acr.exception.ts
    def choose_identity(response, uid, interaction, key)
      identity = Identities.find(key)
      return error_page(response, 'invalid_identity', "unknown test identity #{key}") if identity.nil?
      return error_page(response, 'invalid_acr', 'the identity level is lower than the one requested') if
        rank(identity.acr) < rank(interaction.fetch(:demand).acr)

      configuration.store.advance_interaction(uid, identity: identity)
      page(response, Pages.consent(step(uid, 'consent'), transmitted(interaction, identity)))
    end

    def consent(response, uid, interaction)
      demand = interaction.fetch(:demand)
      code = issued_code(demand, interaction.fetch(:identity))
      configuration.store.close_interaction(uid)

      redirect(response, demand.redirect_uri, code: code, state: demand.state)
    end

    def issued_code(demand, identity)
      configuration.store.issue_code(client_id: demand.client.id, redirect_uri: demand.redirect_uri,
        identity_key: identity.key, nonce: demand.nonce, acr: identity.acr, scopes: demand.scopes,
        amr: demand.amr_requested?)
    end

    def transmitted(interaction, identity) = identity.claims_for(interaction.fetch(:demand).scopes)

    def rank(acr) = AuthorizeRequest::ACR_VALUES.index(acr).to_i
  end
end
