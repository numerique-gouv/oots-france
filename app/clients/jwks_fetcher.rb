# Fetches the public keys a correspondent publishes, so the signature of what it
# signed can be checked: the beneficiary token a French service provider sends,
# and the ID Token FranceConnect+ issues to the demonstration procedure.
#
# Cached, because a token is opened on every request. `force` is what keeps that
# cache from breaking key rotation: the verifier calls back with it when the
# `kid` a token names is absent from the set we hold, which would otherwise
# refuse a freshly published key until expiry.
#
# Addressed by URL and not by the correspondent that publishes it: the two
# callers name their endpoint differently — one derives it from a requester's
# base URL, the other reads it off a discovery document — and neither has to
# become an object this class knows.
class JwksFetcher
  CACHE_DURATION = 5.minutes

  def call(url, force: false)
    JWT::JWK::Set.new(JSON.parse(fetch(url, force:)))
  end

  private

  def fetch(url, force:)
    Rails.cache.fetch("jwks/#{url}", expires_in: CACHE_DURATION, force:) do
      Faraday.new { |builder| builder.response :raise_error }.get(url).body
    end
  end
end
