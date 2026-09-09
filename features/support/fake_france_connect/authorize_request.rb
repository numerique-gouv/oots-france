require 'json'
require 'uri'

module FakeFranceConnect
  # How the fake refuses. The distinction is not cosmetic: a malformed call
  # gets a page and no redirection at all — nothing has established an address
  # the browser could be sent back to — where a call the core merely declines
  # goes back to the procedure carrying its reason.
  # back/libs/oidc-provider/src/filters/oidc-provider-redirect-exception.filter.ts
  Refusal = Data.define(:redirected, :error, :description) do
    def page? = !redirected
  end

  # What the core validates of an `/authorize` call, and how it refuses each
  # way of getting it wrong.
  # back/apps/core-fcp/src/dto/authorize-params.dto.ts
  class AuthorizeRequest
    KNOWN = %w[client_id response_type redirect_uri scope state nonce acr_values claims prompt
               idp_hint ui_locales].freeze
    REQUIRED = %w[client_id response_type redirect_uri scope state nonce acr_values].freeze
    MINIMUM_NONCE_LENGTH = 22
    ACR_VALUES = %w[eidas2 eidas3].freeze
    PROMPTS = %w[login consent].freeze
    IDP_HINT = 'eidas-bridge'.freeze

    CHECKS = %i[unknown_parameter missing_parameter unknown_client undeclared_redirect_uri
                unsupported_response_type unacceptable_scope short_nonce unsupported_prompt
                malformed_claims missing_idp_hint unsupported_acr unsupported_idp_hint].freeze

    attr_reader :client, :refusal

    def initialize(parameters, clients)
      @parameters = parameters
      @client = clients.find { |candidate| candidate.id == parameters['client_id'] }
      @claims = parse_claims
      @refusal = CHECKS.lazy.filter_map { |check| send(check) }.first
    end

    def redirect_uri = parameters['redirect_uri']
    def state = parameters['state']
    def nonce = parameters['nonce'].to_s
    def acr = parameters['acr_values']
    def scopes = parameters.fetch('scope', '').split

    # `{"id_token":{"amr":{"essential":true}}}` — the essential-claims
    # mechanism of OpenID Connect, which the core leaves on:
    # `claimsParameter: { enabled: true }`.
    # back/instances/core-fcp-high/src/config/oidc-provider.ts
    def amr_requested? = !claims&.dig('id_token', 'amr').nil?

    private

    attr_reader :parameters, :claims

    # `nil` says « a `claims` was given and it is not a JSON object » —
    # `malformed_claims` turns that into a refusal, so nothing downstream ever
    # meets a half-read value, and the parameter is read once for both uses.
    def parse_claims
      return {} if parameters['claims'].nil?

      parsed = JSON.parse(parameters['claims'])
      parsed if parsed.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end

    def invalid_parameter
      Refusal.new(redirected: false, error: 'invalid_request', description: 'invalid parameter')
    end

    def unknown_parameter
      invalid_parameter unless (parameters.keys - KNOWN).empty?
    end

    def missing_parameter
      invalid_parameter if REQUIRED.any? { |name| parameters[name].to_s.empty? }
    end

    def unknown_client
      invalid_parameter if client.nil?
    end

    # The `client.nil?` guards below say what the order of CHECKS already
    # guarantees — `unknown_client` runs first and cuts short. Written out so
    # that reordering the list cannot turn a refusal into a crash.
    def undeclared_redirect_uri
      return if client.nil?

      invalid_parameter unless absolute?(redirect_uri) && client.declares_redirect?(redirect_uri)
    end

    def unsupported_response_type
      invalid_parameter unless parameters['response_type'] == 'code'
    end

    def unacceptable_scope
      return if client.nil?

      invalid_parameter unless scopes.include?('openid') && client.grants?(scopes)
    end

    def short_nonce
      invalid_parameter if nonce.length < MINIMUM_NONCE_LENGTH
    end

    # `prompt=none` among the rest: the core forces `login consent` and cannot
    # honour a request to show nothing.
    def unsupported_prompt
      return unless parameters.key?('prompt')

      invalid_parameter unless (parameters['prompt'].to_s.split - PROMPTS).empty?
    end

    def malformed_claims
      invalid_parameter if claims.nil?
    end

    # No `idp_hint`, no mire: the fake plays the European path and nothing
    # else, so it has no list of identity providers to offer.
    def missing_idp_hint
      invalid_parameter if parameters['idp_hint'].to_s.empty?
    end

    # back/libs/core/src/services/core-acr.service.ts
    def unsupported_acr
      return if ACR_VALUES.include?(acr)

      Refusal.new(redirected: true, error: 'invalid_acr',
        description: "acr_value is not valid, should be equal one of these values, expected #{ACR_VALUES.join(',')}, got #{acr}")
    end

    # back/libs/oidc-provider/src/exceptions/oidc-provider-idp-hint.exception.ts
    def unsupported_idp_hint
      return if parameters['idp_hint'] == IDP_HINT

      Refusal.new(redirected: true, error: 'invalid_idp_hint',
        description: 'An idp_hint was provided but is not allowed')
    end

    def absolute?(uri)
      URI.parse(uri.to_s).absolute?
    rescue URI::InvalidURIError
      false
    end
  end
end
