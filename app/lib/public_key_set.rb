# A key set this deployment publishes, so that a correspondent can encrypt for
# it — or check what it signed. Three routes serve one each:
# `/auth/cles_publiques` the key a French service provider encrypts for,
# `/demo/franceconnect/cles_publiques` the key FranceConnect+ encrypts for, and
# `/demo/auth/cles_publiques` the key the demonstration procedure signs its
# beneficiary token with. Which key is a question for the caller; this class is
# given one, and told what it is for.
#
# Built **by subtraction** — secret members removed, the rest published as it
# stands — because enumerating what to publish ties the route to one key type:
# `{ kty, n, e }` describes an RSA key and nothing else. Subtracting keeps the
# choice between RSA and EC free and reversible.
class PublicKeySet
  # The two values RFC 7517 §4.2 defines for `use`.
  ENCRYPTION = 'enc'.freeze
  SIGNATURE = 'sig'.freeze

  # Every private or symmetric member across the key types of RFC 7518.
  # Removing an absent member costs nothing; forgetting one publishes a secret.
  SECRET_MEMBERS = %w[d p q dp dq qi k oth].freeze

  # RFC 7638 fixes which members take part in the thumbprint, and in which
  # order, per key type.
  THUMBPRINT_MEMBERS = {
    'RSA' => %w[e kty n],
    'EC' => %w[crv kty x y],
    'oct' => %w[k kty],
  }.freeze

  # RFC 7517 §4.2 makes `use` the public key's declared purpose, and a signing
  # key published as `enc` would say the opposite of what it is for. Defaulted
  # rather than read from the key, which an operator writes and may leave
  # without one.
  def initialize(private_jwk, use: ENCRYPTION)
    @private_jwk = private_jwk.transform_keys(&:to_s)
    @use = use
  end

  def to_h = { keys: [public_key] }

  # The identifier this set publishes the key under, and therefore the one
  # whoever signs with its private half has to name in the header: the JWT gem
  # mints a `kid` of its own, in hexadecimal, which no reader of this route
  # would ever match.
  def kid = thumbprint

  private

  attr_reader :private_jwk, :use

  def public_key = private_jwk.except(*SECRET_MEMBERS).merge('kid' => thumbprint, 'use' => use)

  # https://datatracker.ietf.org/doc/html/rfc7638
  def thumbprint
    members = THUMBPRINT_MEMBERS.fetch(private_jwk['kty']) do
      raise ConfigurationError, I18n.t('lib.public_key_set.unknown_key_type', type: private_jwk['kty'])
    end

    canonical = members.index_with { |member| private_jwk.fetch(member) }

    Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(JSON.generate(canonical)), padding: false)
  end
end
