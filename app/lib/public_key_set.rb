# The key set OOTS-France publishes, so a service provider can encrypt the
# beneficiary token for us.
#
# Built **by subtraction** — secret members removed, the rest published as it
# stands — because enumerating what to publish ties the route to one key type:
# `{ kty, n, e }` describes an RSA key and nothing else. Subtracting keeps the
# choice between RSA and EC free and reversible.
class PublicKeySet
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

  def initialize(private_jwk = Settings.private_key_jwk)
    @private_jwk = private_jwk.transform_keys(&:to_s)
  end

  def to_h = { keys: [public_key] }

  private

  attr_reader :private_jwk

  def public_key = private_jwk.except(*SECRET_MEMBERS).merge('kid' => thumbprint, 'use' => 'enc')

  # https://datatracker.ietf.org/doc/html/rfc7638
  def thumbprint
    members = THUMBPRINT_MEMBERS.fetch(private_jwk['kty']) do
      raise ConfigurationError, "Type de clé inconnu : « #{private_jwk['kty']} »."
    end

    canonical = members.index_with { |member| private_jwk.fetch(member) }

    Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(JSON.generate(canonical)), padding: false)
  end
end
