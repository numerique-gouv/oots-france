require 'digest'
require 'json'
require 'jwe'
require 'jwt'
require 'net/http'
require 'openssl'
require 'securerandom'

module FakeFranceConnect
  # What the fake signs and encrypts, and the pseudonym it hands each service
  # provider.
  #
  # Signed with a key of its own and then encrypted for the procedure — never
  # the reverse: the procedure must be the only reader, and the signature must
  # survive inside what it opens.
  class Tokens
    SIGNING_ALGORITHM = 'ES256'.freeze
    SIGNING_CURVE = 'prime256v1'.freeze
    ENCRYPTION_METHOD = 'A256GCM'.freeze

    # FranceConnect+ accepts `ECDH-ES` as well, and the fake cannot: `jwe`
    # 1.1.1 ships `rsa_oaep`, `rsa_oaep_256`, `rsa15`, the `A*KW` family and
    # `dir`, and nothing else. Refusing it aloud is the point — a token
    # encrypted under a silently substituted algorithm would be opened by
    # nobody, far from here. `scripts/ci/prepare_environment.sh` meets the same
    # limit and generates an RSA key for the same reason.
    KEY_MANAGEMENT_ALGORITHMS = %w[RSA-OAEP RSA-OAEP-256].freeze

    class UnsupportedKeyManagement < StandardError; end

    # The secret is drawn at boot, and so is the same for every authentication
    # of one run: that is what makes a `sub` stable across two authentications
    # and different across two deployments.
    def initialize(procedure_key_set_url:, secret: SecureRandom.hex(32))
      @procedure_key_set_url = procedure_key_set_url
      @secret = secret
      @signing_keys = [OpenSSL::PKey::EC.generate(SIGNING_CURVE)]
      @mutex = Mutex.new
    end

    def key_set = { keys: exported_keys }

    def kids = exported_keys.map { |key| key.fetch(:kid) }

    # FranceConnect+ renews its signing keys, and a reader holding a stale JWKS
    # has to fetch it again. The former keys stay published: a token signed a
    # minute ago is still verifiable.
    def rotate = mutex.synchronize { signing_keys.unshift(OpenSSL::PKey::EC.generate(SIGNING_CURVE)) }

    def seal(claims) = encrypt(sign(claims))

    # `computeSubV1`: a digest of the service provider's reference, of a digest
    # of the identity and of a secret of the core's own, in hexadecimal, with
    # `v1` appended — 64 characters and two, and no resemblance to the
    # `XX/YY/…` identifier the node yields, which never leaves the fake.
    # back/libs/cryptography-eidas/src/cryptography-eidas.service.ts
    def subject_for(client_id, identity)
      identity_digest = Digest::SHA256.hexdigest(identity.eidas_identifier)

      "#{Digest::SHA256.hexdigest("#{client_id}#{identity_digest}#{secret}")}v1"
    end

    private

    attr_reader :procedure_key_set_url, :secret, :signing_keys, :mutex

    # `rotate` unshifts on the scenario's thread while `/jwks` iterates on
    # WEBrick's: the copy is taken under the lock, and read outside it.
    def exported_keys = mutex.synchronize { signing_keys.dup }.map { |key| exported(key) }

    def exported(key) = JWT::JWK.new(key).export

    def sign(claims)
      key = mutex.synchronize { signing_keys.first }

      JWT.encode(claims, key, SIGNING_ALGORITHM, kid: exported(key)[:kid])
    end

    # The algorithm is read from the key, never guessed: choosing one for a key
    # that declares none would encrypt under something nobody picked, and the
    # first reader to refuse it would be a real one, far from here.
    def encrypt(payload)
      published = procedure_public_key
      algorithm = published['alg'] || raise("#{procedure_key_set_url} a publié une clé sans alg.")

      unless KEY_MANAGEMENT_ALGORITHMS.include?(algorithm)
        raise UnsupportedKeyManagement,
          "#{algorithm} n'est pas géré par le gem jwe 1.1.1 : #{KEY_MANAGEMENT_ALGORITHMS.join(', ')}."
      end

      JWE.encrypt(payload, JWT::JWK.new(published).verify_key, alg: algorithm, enc: ENCRYPTION_METHOD)
    end

    # Read on the route the procedure publishes it on, at every issuance, and
    # never derived alongside: deriving it is exactly what let a broken
    # key-publishing route go unnoticed for months — the test never called it.
    def procedure_public_key
      response = Net::HTTP.get_response(URI.parse(procedure_key_set_url))
      raise "#{procedure_key_set_url} a répondu #{response.code}." unless response.is_a?(Net::HTTPSuccess)

      # A published set that is present but empty would sail through as `nil`
      # and resurface, three calls later, as a `NoMethodError` naming nothing.
      JSON.parse(response.body).fetch('keys').first ||
        raise("#{procedure_key_set_url} n'a publié aucune clé.")
    end
  end
end
