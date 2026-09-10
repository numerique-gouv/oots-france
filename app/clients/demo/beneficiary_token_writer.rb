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
    # A set fetched over HTTP is unusable in more ways than being unreachable,
    # and `Faraday` only names that one. The two families the JWT gem really
    # raises for such a document are what the rescue lists, rather than what one
    # would guess: `JSON::ParserError` for a body that is no JSON — a
    # maintenance page answered with a `200` — and `JWT::JWKError` for JSON that
    # is no usable key, which `JWT::JWK.create_from` raises eagerly while the
    # set is being built (`kty` absent or unsupported, an EC key without its
    # coordinates, a curve the gem does not hold). A set published empty is no
    # exception at all: it is simply `nil` where a key was expected.
    #
    # The two readers of this deployment catch `JWT::JWKError` through its
    # ancestor `JWT::DecodeError`, which their own call to `JWT.decode` puts on
    # their list. This writer decodes no token, so it names the family it needs
    # — and names it, rather than inheriting it by chance. Narrow to this single
    # call.
    def encryption_key
      published = key_fetcher.call(key_set_url).keys.first
      raise UnusableKeySetError, I18n.t('clients.demo.beneficiary_token_writer.no_key', url: key_set_url) if published.nil?

      published.verify_key
    rescue JSON::ParserError, JWT::JWKError, ArgumentError, TypeError => e
      raise UnusableKeySetError,
        I18n.t('clients.demo.beneficiary_token_writer.unreadable', url: key_set_url, error: e.message)
    end

    def key_set_url = "#{Settings.oots_france_url}/auth/cles_publiques"
  end
end
