module Demo
  # Seals the beneficiary token the demonstration procedure sends, which
  # `BeneficiaryToken` opens at the other end: a JWT **signed by the procedure**,
  # wrapped in a JWE **encrypted for OOTS-France**.
  #
  # The claim names are those of the contract `docs/oots_context.md` fixes
  # between a French procedure and this component, and no TDD chapter governs
  # them. What travels is what the authentication attested and nothing else: the
  # four mandatory claims, then the three FranceConnect+ returns only sometimes.
  # Never the `sub`, which is a pseudonym of the portal's own, per service
  # provider, and names no person outside it.
  class BeneficiaryTokenWriter
    # The only signature `BeneficiaryToken::SIGNATURE` admits, hence a P-256 key
    # and not one of the RSA keys this deployment decrypts with.
    SIGNATURE = 'ES256'.freeze

    # Long enough for a directory lookup and an AS4 submission, short enough
    # that a token read off a log is worth nothing by the time it is read.
    VALIDITY = 10.minutes

    def initialize(key_fetcher: JwksFetcher.new, clock: Clock.new)
      @key_fetcher = key_fetcher
      @clock = clock
    end

    def call(identity)
      JWE.encrypt(signed(identity), encryption_key,
        alg: BeneficiaryToken::KEY_MANAGEMENT, enc: BeneficiaryToken::CONTENT_ENCRYPTION)
    end

    private

    attr_reader :key_fetcher, :clock

    # The `kid` comes from `PublicKeySet` and not from the JWT gem: the route
    # rewrites it to the RFC 7638 thumbprint, and a header naming the gem's own
    # hexadecimal one would match no key in the set the reader fetches.
    def signed(identity)
      jwk = Settings.demo_signing_key_jwk

      JWT.encode(claims(identity), JWT::JWK.new(jwk).signing_key, SIGNATURE, kid: PublicKeySet.new(jwk).kid)
    end

    # `compact_blank` and not `compact`: what FranceConnect+ did not return
    # reaches here as nil, and what it returned empty says as little. Either
    # way the claim is absent rather than blank — `BeneficiaryToken` refuses a
    # blank `sexe` outright, and would refuse a blank `lieuNaissance` on the
    # request the token becomes.
    def claims(identity)
      {
        'niveauGarantie' => identity.level_of_assurance,
        'nomUsage' => identity.family_name,
        'prenom' => identity.given_name,
        'dateNaissance' => identity.birthdate,
        'identifiantEidas' => identity.eidas_identifier,
        'sexe' => identity.gender,
        'lieuNaissance' => identity.place_of_birth,
      }.compact_blank.merge('exp' => expiry)
    end

    def expiry = Time.zone.parse(clock.now).to_i + VALIDITY.to_i

    # Read from the route rather than derived from `Settings.private_key_jwk`.
    # Reading it is what makes the demonstration exercise the publishing route;
    # deriving it would sidestep that route, and leave a broken one invisible.
    #
    # The URL is resolved here, outside the rescue below: `Settings` raises on a
    # deployment that named none, and that is ours to hear.
    def encryption_key
      url = key_set_url

      read_key(url) || raise(UnusableKeySetError, I18n.t('clients.demo.beneficiary_token_writer.no_key', url:))
    end

    # Everything this body does is turn a document read from elsewhere into a key
    # object, so nothing of ours can be swallowed by rescuing broadly — and
    # broadly is the only way that holds. Enumerating what the gem raises here
    # was tried four times, each list read from its sources, and a fresh test
    # broke each one. What the four shapes of an unusable published set really
    # raise, reproduced against the JSON this deployment's own route serves:
    #
    #   a body that is no JSON at all      JSON::ParserError
    #   `kty` absent or unsupported        JWT::JWKError
    #   a coordinate in broken base64      JWT::Base64DecodeError
    #   a point that is not on the curve   OpenSSL::PKey::EC::Point::Error
    #
    # The first two are raised while the set is assembled, the last two only when
    # the key is built from it. And the trap no reading of the hierarchy gives:
    # `Base64DecodeError` is a **sister** of `JWT::JWKError` under
    # `JWT::DecodeError`, and `EC::Point::Error` a sister of
    # `OpenSSL::PKey::PKeyError` rather than its child — so catching either
    # parent still misses the other branch. A fifth list would be a fifth bet.
    #
    # `Faraday::Error` alone travels on: unreachable and unusable are two
    # different things to tell the user, and the caller already names the first.
    def read_key(url)
      key_fetcher.call(url).keys.first&.verify_key
    rescue Faraday::Error
      raise
    rescue StandardError => e
      raise UnusableKeySetError,
        I18n.t('clients.demo.beneficiary_token_writer.unreadable', url:, error: e.message)
    end

    def key_set_url = "#{Settings.oots_france_url}/auth/cles_publiques"
  end
end
