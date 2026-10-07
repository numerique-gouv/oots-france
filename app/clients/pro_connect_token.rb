# Verifies what ProConnect signs for the administration space: the ID Token,
# and the UserInfo response when it comes as a JWT. Signed and not encrypted,
# unlike what FranceConnect+ seals for the demonstration.
class ProConnectToken
  # The two asymmetric algorithms ProConnect signs with, fixed rather than read
  # from the token — letting a token name the algorithm that verifies it is an
  # algorithm-confusion surface. Never `HS256`, whose key would be the
  # `client_secret` this deployment shares with ProConnect: a token signed with
  # it proves only that someone holds that secret.
  # https://partenaires.proconnect.gouv.fr/docs/fournisseur-service/implementation_technique
  SIGNATURE = %w[RS256 ES256].freeze

  # The two forms of a UserInfo response, told apart by their media type alone.
  JSON_TYPE = 'application/json'.freeze
  JWT_TYPE = 'application/jwt'.freeze

  def initialize(client:, key_fetcher: JwksFetcher.new)
    @client = client
    @key_fetcher = key_fetcher
  end

  # Signature, `iss`, `aud` and expiry by the gem, then the `nonce` « pour
  # empêcher les attaques par rejeu », present and equal in constant time.
  def id_token_claims(signed_token, nonce:)
    claims = verified(signed_token, iss: client.issuer, verify_iss: true,
      aud: client.client_id, verify_aud: true, required_claims: %w[exp])
    return claims if nonce.present? && ActiveSupport::SecurityUtils.secure_compare(nonce.to_s, claims['nonce'].to_s)

    raise ProConnectError, I18n.t('clients.pro_connect_token.unexpected_nonce')
  end

  def userinfo_claims(body, content_type)
    case media_type(content_type)
    when JSON_TYPE then ProConnectAnswer.object(JSON.parse(body.to_s), :userinfo)
    when JWT_TYPE then verified(body)
    else raise ProConnectError, I18n.t('clients.pro_connect_token.unexpected_type', type: content_type.to_s)
    end
  rescue JSON::ParserError => e
    raise ProConnectError, I18n.t('clients.pro_connect_token.unreadable_userinfo', error: e.message)
  end

  private

  attr_reader :client, :key_fetcher

  # The fixed values come **last**: a `**hash` splatted after explicit keywords
  # overrides them, so writing them first would let a caller name the algorithm.
  def verified(signed_token, **verification)
    payload, = JWT.decode(signed_token.to_s, nil, true, **verification, algorithms: SIGNATURE, jwks: key_set)

    ProConnectAnswer.object(payload, :claims)
  rescue ProConnectError
    raise
  # Exhaustive for the reason `FranceConnectToken#claims` gives: the key set is
  # read inside this call, and the gem lets what the loader raises travel out
  # untranslated, as it lets a claims set that is not an object crash while it
  # indexes `exp`.
  rescue JWT::DecodeError, JSON::ParserError, ArgumentError, TypeError, NoMethodError => e
    raise ProConnectError, I18n.t('clients.pro_connect_token.invalid', error: e.message)
  end

  # A callback and not a resolved set: the verifier asks again with
  # `invalidate` when the `kid` is absent, which is what lets ProConnect rotate
  # its keys without waiting for our cache.
  def key_set = ->(options) { key_fetcher.call(client.jwks_url, force: options[:invalidate]) }

  def media_type(content_type) = content_type.to_s.split(';').first.to_s.strip.downcase
end
