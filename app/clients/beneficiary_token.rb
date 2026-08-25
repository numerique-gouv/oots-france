# Opens the token a French service provider sends to name the beneficiary: a
# JWT **signed by the requester**, wrapped in a JWE **encrypted for us**. Our
# private key opens the envelope, the requester's public key authenticates what
# is inside — attesting the sender, never its standing to act for the
# beneficiary declared. Stub, tracked as OOTS-58.
class BeneficiaryToken
  # Fixed here, and not read from the token: letting a token name the algorithm
  # used to open it is an algorithm-confusion surface where the attacker picks
  # the ground.
  KEY_MANAGEMENT = 'RSA-OAEP-256'.freeze
  CONTENT_ENCRYPTION = 'A256GCM'.freeze
  SIGNATURE = ['ES256'].freeze

  def initialize(requester, key_fetcher: JwksFetcher.new)
    @requester = requester
    @key_fetcher = key_fetcher
  end

  def beneficiary(encrypted_token)
    payload = verified_payload(encrypted_token)

    NaturalPerson.new(
      family_name: payload['nomUsage'],
      given_name: payload['prenom'],
      date_of_birth: payload['dateNaissance'],
      eidas_identifier: payload['identifiantEidas'],
    ).validate!(:token_beneficiary, error: InvalidTokenError)
  rescue InvalidTokenError
    raise
  # Narrow, because a `StandardError` here would also catch the call to the
  # requester's JWKS endpoint and blame their token for their server being
  # down. Exhaustive, because `JWE::DecodeError`, `BadCEK` and
  # `NotImplementedError` are **siblings** of `InvalidData`, not subclasses,
  # and `ArgumentError` is what `invalid base64` raises.
  rescue JWT::DecodeError, JWE::InvalidData, JWE::DecodeError, JWE::BadCEK,
         JWE::NotImplementedError, JSON::ParserError, OpenSSL::PKey::PKeyError,
         ArgumentError => e
    raise InvalidTokenError, I18n.t('clients.beneficiary_token.invalid', error: e.message)
  end

  private

  attr_reader :requester, :key_fetcher

  def verified_payload(encrypted_token)
    signed_token = decrypt(encrypted_token)
    payload, = JWT.decode(signed_token, nil, true, algorithms: SIGNATURE, jwks: key_set)

    payload
  end

  # A callback and not a resolved set: the verifier asks again with
  # `invalidate` when the `kid` is absent, which is what lets a requester
  # rotate its keys without waiting for our cache to expire.
  def key_set = ->(options) { key_fetcher.call(requester, force: options[:invalidate]) }

  def decrypt(encrypted_token)
    header = JSON.parse(JWE::Base64.jwe_decode(encrypted_token.split('.').first))
    reject_unless_expected(header)

    JWE.decrypt(encrypted_token, private_key)
  end

  # Before decrypting, not after: the point is never to run an algorithm we
  # did not choose.
  def reject_unless_expected(header)
    return if header['alg'] == KEY_MANAGEMENT && header['enc'] == CONTENT_ENCRYPTION

    raise InvalidTokenError,
      I18n.t('clients.beneficiary_token.unexpected_algorithms',
        announced: "#{header['alg']}/#{header['enc']}",
        expected: "#{KEY_MANAGEMENT}/#{CONTENT_ENCRYPTION}")
  end

  def private_key = JWT::JWK.new(Settings.private_key_jwk).signing_key
end
