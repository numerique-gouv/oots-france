# Fetches the public keys a requester publishes, so the signature of a
# beneficiary token can be checked.
#
# Cached, because a token is opened on every request. `force` is what keeps
# that cache from breaking key rotation: the verifier calls back with it when
# the `kid` a token names is absent from the set we hold, which would otherwise
# refuse a freshly published key until expiry.
class JwksFetcher
  CACHE_DURATION = 5.minutes

  def call(requester, force: false)
    JWT::JWK::Set.new(JSON.parse(fetch(requester.jwks_url, force:)))
  end

  private

  def fetch(url, force:)
    Rails.cache.fetch("jwks/#{url}", expires_in: CACHE_DURATION, force:) do
      Faraday.new { |builder| builder.response :raise_error }.get(url).body
    end
  end
end
