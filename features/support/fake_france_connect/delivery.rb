require 'jwt'
require_relative 'identities'
require_relative 'pages'
require_relative 'responses'
require_relative 'store'
require_relative 'tokens'

module FakeFranceConnect
  # What the procedure calls once its browser has come back: `/token`,
  # `/userinfo`, `/session/end`.
  class Delivery
    include Responses

    ID_TOKEN_LIFETIME = Store::ACCESS_TOKEN_LIFETIME
    # The six the DTO declares, and not the four one might expect: `logout_hint`
    # and `ui_locales` are optional there too, so a client sending either is not
    # sending an unknown parameter.
    # back/libs/oidc-provider/src/dto/logout-params.dto.ts
    LOGOUT_PARAMETERS = %w[id_token_hint post_logout_redirect_uri state client_id
                           logout_hint ui_locales].freeze

    def initialize(configuration)
      @configuration = configuration
    end

    # `client_secret_post` and nothing else: the credentials travel in the
    # body, never in an `Authorization: Basic` header, which the core does not
    # accept either.
    # back/instances/core-fcp-high/src/config/oidc-provider.ts
    def token(request, response)
      parameters = request.query.transform_values(&:to_s)
      client = authenticated_client(parameters)
      return refuse(response, 'invalid_client') if client.nil?

      granted = claim(parameters, client)
      return refuse(response, 'invalid_grant') if granted.nil?

      json(response, issue(client, granted))
    end

    def userinfo(request, response)
      held = configuration.store.access_token(bearer(request))
      return refuse(response, 'invalid_token', status: 401) if held.nil?

      response['Content-Type'] = 'application/jwt'
      response.body = configuration.tokens.seal(userinfo_claims(held))
    end

    def session_end(request, response)
      parameters = request.query.transform_values(&:to_s)
      hint = verified_hint(parameters)
      return error_page(response) if hint.nil? || (parameters.keys - LOGOUT_PARAMETERS).any?

      target = parameters['post_logout_redirect_uri'].to_s
      return page(response, Pages.logged_out) unless declared?(parameters, hint, target)

      redirect(response, target, state: parameters['state'])
    end

    private

    attr_reader :configuration

    # `sub` and what the requested scopes cover, and nothing else: no
    # identifier, no country, no `birthcountry`, no `email`.
    def userinfo_claims(held)
      identity = Identities.find(held.fetch(:identity_key))

      { 'sub' => held.fetch(:sub) }.merge(identity.claims_for(held.fetch(:scopes)))
    end

    def refuse(response, error, status: 400)
      response.status = status
      json(response, error: error)
    end

    def authenticated_client(parameters)
      client = configuration.clients.find { |candidate| candidate.id == parameters['client_id'] }

      client if client && parameters['client_secret'] == client.secret
    end

    # Single use and thirty seconds, both settled by the store: what comes back
    # nil here is a code replayed, expired, issued to another client, or
    # presented with a `redirect_uri` other than the one it was issued for —
    # RFC 6749 §4.1.3 asks the token endpoint for that last comparison.
    # https://datatracker.ietf.org/doc/html/rfc6749#section-4.1.3
    def claim(parameters, client)
      return unless parameters['grant_type'] == 'authorization_code'

      granted = configuration.store.claim_code(parameters['code'].to_s)
      return if granted.nil? || granted.fetch(:client_id) != client.id

      granted if granted.fetch(:redirect_uri) == parameters['redirect_uri']
    end

    def issue(client, granted)
      identity = Identities.find(granted.fetch(:identity_key))
      subject = configuration.tokens.subject_for(client.id, identity)
      access_token = configuration.store.issue_access_token(identity_key: identity.key, sub: subject,
        scopes: granted.fetch(:scopes))

      { access_token: access_token, token_type: 'Bearer', expires_in: Store::ACCESS_TOKEN_LIFETIME,
        id_token: configuration.tokens.seal(id_token_claims(client, granted, subject)) }
    end

    def id_token_claims(client, granted, subject)
      issued_at = configuration.store.now
      claims = { 'iss' => configuration.issuer, 'sub' => subject, 'aud' => client.id,
                 'iat' => issued_at, 'exp' => issued_at + ID_TOKEN_LIFETIME,
                 'nonce' => granted.fetch(:nonce), 'acr' => granted.fetch(:acr) }

      granted.fetch(:amr) ? claims.merge('amr' => %w[eidas]) : claims
    end

    def bearer(request) = request['Authorization'].to_s.delete_prefix('Bearer ')

    # The hint is the ID Token once decrypted: the fake reads it back with its
    # own signing keys, expired or not — a logout follows a session that has
    # had time to run.
    def verified_hint(parameters)
      hint = parameters['id_token_hint'].to_s
      return if hint.empty?

      JWT.decode(hint, nil, true, algorithms: [Tokens::SIGNING_ALGORITHM], verify_expiration: false,
        jwks: configuration.tokens.key_set).first
    rescue JWT::DecodeError => e
      warn("id_token_hint refusé — #{e.class}: #{e.message}")
      nil
    end

    def declared?(parameters, hint, target)
      return false if target.empty?

      client = configuration.clients.find do |candidate|
        candidate.id == (parameters['client_id'].to_s.empty? ? hint['aud'] : parameters['client_id'])
      end

      client&.declares_post_logout_redirect?(target) || false
    end
  end
end
