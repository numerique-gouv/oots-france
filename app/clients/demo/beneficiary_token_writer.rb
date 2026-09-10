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
    # Deriving it is exactly what let a broken key-publishing route go
    # unnoticed once: nothing called it.
    def encryption_key
      key_fetcher.call("#{Settings.oots_france_url}/auth/cles_publiques").keys.first.verify_key
    end
  end
end
