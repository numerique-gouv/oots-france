# The query transaction the Evidence Broker and the Data Service Directory
# share: a `GET «base»/rest/search?queryId=…`, answered with a RegRep document
# (chapter 3.6.2).
#
# Cached because the data is close to static and three of these calls sit on
# the path of every evidence request. Chapter 3.4 recommends a caching proxy
# for the same reason, but the acceptance instance sends no `Cache-Control`,
# `ETag` or `Expires`: freshness cannot be derived from the answer, so it is
# chosen here.
class CommonServicesQuery
  SEARCH_PATH = 'rest/search'.freeze

  def initialize(service, instance: nil, signature: nil, connection: nil)
    @instance = instance || CommonServicesInstance.new(service)
    @signature = signature || CommonServicesSignature.new
    @connection = connection
  end

  # Read and write rather than `fetch`, so that what is written is decided
  # after the answer has been read: the parser is what tells a refusal from an
  # answer, and a refusal must not be written. It arrives with the same 200 and
  # the same valid signature as an answer, and cached it would keep serving a
  # directory's passing failure for the whole freshness window, long after the
  # directory recovered.
  def search(parameters, parser:)
    url = "#{@instance.base_url.chomp('/')}/#{SEARCH_PATH}"
    key = cache_key(url, parameters, parser)
    cached = Rails.cache.read(key)
    return parser.new(cached) if cached

    body = fetch(url, parameters)
    read = parser.new(body)
    remember(key, body)

    read
  end

  private

  def fetch(url, parameters)
    response = connection.get(url, parameters)
    @signature.verify!(
      body: response.body,
      digest: response.headers['digest'],
      signature: response.headers['oots-response-sig'],
    )

    response.body
  rescue Faraday::Error => e
    raise CommonServicesError, "Annuaire injoignable (#{url}) : #{e.message}."
  end

  # A cache is an optimisation: one that cannot be written must not cost the
  # answer that was already obtained.
  def remember(key, body)
    Rails.cache.write(key, body, expires_in: Settings.common_services_cache_duration)
  rescue StandardError => e
    Rails.logger.warn("Réponse d'annuaire non mise en cache (#{key}) : #{e.message}")
  end

  # The parser belongs to the key because nothing in this signature stops a
  # caller from asking two parsers the same question — the Evidence Broker
  # answers both of its queries at one address — and one would then read back
  # what the other cached. Its two queries differ by their parameters today, so
  # this guards a shape rather than a live collision. The specification is
  # there for another reason: a file store, which is what Rails falls back to,
  # outlives a deployment, and answers of a version no longer asked for must
  # not.
  def cache_key(url, parameters, parser)
    seed = [url, parameters.sort, parser.name, CommonServicesSpecification::IDENTIFIER]

    "common_services/#{Digest::SHA256.hexdigest(seed.to_json)}"
  end

  # Lazily, so the timeouts are read now and not when the file loads.
  def connection
    @connection ||= Faraday.new do |builder|
      builder.headers['Accept'] = CommonServicesSpecification::MEDIA_TYPE
      builder.headers['Accept-Version'] = CommonServicesSpecification::IDENTIFIER
      builder.request :retry, max: 2, interval: 0.5, backoff_factor: 2
      builder.response :raise_error
      builder.options.timeout = Settings.common_services_timeout
      builder.options.open_timeout = Settings.common_services_timeout
      builder.adapter :net_http
    end
  end
end
