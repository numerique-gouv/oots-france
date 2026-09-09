# Opens what FranceConnect+ seals for the demonstration procedure: a JWT
# **signed by the portal**, wrapped in a JWE **encrypted for us**. The ID Token
# and the UserInfo response both arrive this way.
#
# Mirror of `BeneficiaryToken`, whose shape and error handling it follows: our
# private key opens the envelope, the portal's published keys authenticate what
# is inside. The two differ where the correspondents differ — the algorithms are
# read off the key *we* publish, since it is that declaration FranceConnect+
# encrypts under, and the claims to verify are the caller's to name, an ID Token
# carrying an issuer and an audience where a UserInfo response carries neither.
class FranceConnectToken
  # `ES256`, and fixed rather than read from the token: letting a token name the
  # algorithm used to verify it is an algorithm-confusion surface where the
  # attacker picks the ground.
  # https://docs.partenaires.franceconnect.gouv.fr/fs/fs-technique/fs-technique-chiffrement-signature-fcplus/
  SIGNATURE = %w[ES256].freeze

  # The only content encryption FranceConnect+ pairs with either of the two key
  # management algorithms it accepts.
  CONTENT_ENCRYPTION = 'A256GCM'.freeze

  def initialize(client: FranceConnectClient.new, key_fetcher: JwksFetcher.new)
    @client = client
    @key_fetcher = key_fetcher
  end

  # The signed JWT the envelope holds, which is also what `/session/end` wants
  # as `id_token_hint` — « afin que FranceConnect+ puisse retrouver la
  # session ». Kept apart from `claims` so that the ID Token is opened once and
  # the hint costs no second decryption.
  def signed(sealed)
    header = JSON.parse(JWE::Base64.jwe_decode(sealed.to_s.split('.').first.to_s))
    reject_unless_expected(header)

    JWE.decrypt(sealed, private_key)
  rescue JSON::ParserError, JWE::InvalidData, JWE::DecodeError, JWE::BadCEK,
         JWE::NotImplementedError, OpenSSL::PKey::PKeyError, ArgumentError => e
    raise FranceConnectError, I18n.t('clients.france_connect_token.unreadable', error: e.message)
  end

  def claims(signed_token, **verification)
    payload, = JWT.decode(signed_token, nil, true, algorithms: SIGNATURE, jwks: key_set, **verification)

    payload
  rescue JWT::DecodeError => e
    raise FranceConnectError, I18n.t('clients.france_connect_token.invalid', error: e.message)
  end

  def open(sealed, **verification) = claims(signed(sealed), **verification)

  private

  attr_reader :client, :key_fetcher

  # A callback and not a resolved set: the verifier asks again with `invalidate`
  # when the `kid` is absent, which is what lets FranceConnect+ rotate the
  # signing keys it renews « régulièrement » without waiting for our cache.
  def key_set = ->(options) { key_fetcher.call(client.jwks_url, force: options[:invalidate]) }

  # Compared against the key **we** publish, and not against a list: it is that
  # `alg` FranceConnect+ reads at each issuance and encrypts under, so anything
  # else in the header is a token we did not address. `Settings::Contract` has
  # already refused a key declaring an algorithm the portal does not accept.
  def reject_unless_expected(header)
    expected = private_jwk['alg']
    return if header['alg'] == expected && header['enc'] == CONTENT_ENCRYPTION

    raise FranceConnectError,
      I18n.t('clients.france_connect_token.unexpected_algorithms',
        announced: "#{header['alg']}/#{header['enc']}",
        expected: "#{expected}/#{CONTENT_ENCRYPTION}")
  end

  def private_jwk = @private_jwk ||= Settings.france_connect_private_key_jwk

  def private_key = JWT::JWK.new(private_jwk).signing_key
end
