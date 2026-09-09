require 'securerandom'

module FakeFranceConnect
  # What the fake remembers between two calls: an authentication under way, an
  # authorization code, an access token — each with the lifetime the core gives
  # it.
  #
  # In memory, and behind a mutex: WEBrick serves each request in a thread of
  # its own, and the scenario's commands arrive on yet another.
  class Store
    # back/instances/core-fcp-high/src/config/oidc-provider.ts
    AUTHORIZATION_CODE_LIFETIME = 30
    ACCESS_TOKEN_LIFETIME = 60

    def initialize(clock: -> { Time.now.to_i })
      @clock = clock
      @interactions = {}
      @codes = {}
      @access_tokens = {}
      @mutex = Mutex.new
    end

    def now = clock.call

    def open_interaction(demand:)
      SecureRandom.uuid.tap { |uid| mutex.synchronize { interactions[uid] = { demand: demand } } }
    end

    # A copy, so that what the lock protects cannot be edited from outside it.
    def interaction(uid) = mutex.synchronize { interactions[uid]&.dup }

    def advance_interaction(uid, identity:)
      mutex.synchronize { interactions[uid] = interactions.fetch(uid).merge(identity: identity) }
    end

    def close_interaction(uid) = mutex.synchronize { interactions.delete(uid) }

    # Named one by one rather than taken as a hash: a key mistyped on the way
    # in would otherwise be stored happily and fail at another class's `fetch`.
    def issue_code(client_id:, redirect_uri:, identity_key:, nonce:, acr:, scopes:, amr:)
      granted = { client_id: client_id, redirect_uri: redirect_uri, identity_key: identity_key,
                  nonce: nonce, acr: acr, scopes: scopes, amr: amr, issued_at: now }

      SecureRandom.hex(32).tap { |code| mutex.synchronize { codes[code] = granted } }
    end

    # Single use and short-lived, both enforced here: the entry is removed
    # whatever its age, so a replay finds nothing whether the first use
    # succeeded or the code had already expired.
    def claim_code(code)
      claimed = mutex.synchronize { codes.delete(code) }
      return if claimed.nil?

      claimed if now - claimed.fetch(:issued_at) <= AUTHORIZATION_CODE_LIFETIME
    end

    # The scenario has to see a code expire, and cannot wait thirty seconds for
    # it: ageing the codes that exist is surgical where moving the clock would
    # leak into the scenarios that follow.
    def age_codes(seconds) = age(codes, seconds)

    def age_access_tokens(seconds) = age(access_tokens, seconds)

    def issue_access_token(identity_key:, sub:, scopes:)
      held = { identity_key: identity_key, sub: sub, scopes: scopes, issued_at: now }

      SecureRandom.hex(32).tap { |token| mutex.synchronize { access_tokens[token] = held } }
    end

    def access_token(token)
      held = mutex.synchronize { access_tokens[token]&.dup }
      return if held.nil?

      held if now - held.fetch(:issued_at) <= ACCESS_TOKEN_LIFETIME
    end

    private

    attr_reader :clock, :interactions, :codes, :access_tokens, :mutex

    def age(entries, seconds)
      mutex.synchronize { entries.each_value { |held| held[:issued_at] -= seconds } }
    end
  end
end
