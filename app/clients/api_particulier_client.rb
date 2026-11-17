# API Particulier, the French registry gateway France reads the student status
# from: `GET /v3/mesri/statut_etudiant/identite`, matched on the pivot identity
# (`PivotIdentity`), with a bearer token and the SIRET of the recipient the
# habilitation names. https://particulier.api.gouv.fr/catalogue/mesri/statut_etudiant
#
# Three outcomes and no exception: the data found, nobody found, or the
# exception of chapter 4.10 §3 a failing registry is answered with.
#
# Asked for the attestation, the call carries `X-Generate-Proof: pdf`, and API
# Particulier adds to its answer `links.attestation_pdf`, a short-lived link to
# the PDF it generated, which is downloaded without authentication
# (https://github.com/datagouv/apistration/pull/670). Production ignores the
# header until https://github.com/datagouv/apistration/pull/671: no link is
# then the registry's failure, not the data in its place.
class ApiParticulierClient
  PATH = '/v3/mesri/statut_etudiant/identite'.freeze
  PROOF = { 'X-Generate-Proof' => 'pdf' }.freeze

  # Longer than the ten seconds API Particulier waits for the ministry before
  # answering `504`, so that the ministry's timeout is the one reported.
  TIMEOUT = 15

  NOBODY_FOUND = '25003'.freeze

  # Chapter 4.7 §5: « The size of each evidence, prior to the GZIP compression
  # applied by AS4, does not exceed 25 MB » — read as the stricter of MB and MiB.
  MAX_ATTESTATION_SIZE = 25_000_000

  # `data` as API Particulier returned it, re-serialised in the order of its
  # keys; and the bytes of the attestation, where it was asked for.
  Found = Data.define(:document, :attestation) do
    def initialize(document:, attestation: nil) = super
  end
  NotFound = Data.define
  Unobtainable = Data.define(:exception)

  class AttestationTooLarge < StandardError; end

  def initialize(connection: nil)
    @connection = connection
  end

  def student_status(identity, attestation: false)
    response = connection.get(PATH, identity.to_query(Settings.api_particulier_recipient), attestation ? PROOF : {})
    outcome = outcome_of(response)
    return outcome unless attestation && outcome.is_a?(Found)

    with_attestation(outcome, JSON.parse(response.body))
  rescue Faraday::TimeoutError => e
    unobtainable(EdmException::TIMEOUT, e.class.name)
  rescue Faraday::Error, JSON::ParserError => e
    unobtainable(EdmException::QUERY, e.class.name)
  rescue AttestationTooLarge
    unobtainable(EdmException::QUERY, :attestation_too_large)
  end

  private

  # `404` with `25003` is « Entité non trouvée »; any other `404` is an address
  # API Particulier does not serve, a deployment's mistake and not an answer.
  # `504` is `25002`, the ministry not answering in time. A refused token is
  # the operator's to fix, and said in the log for it.
  def outcome_of(response)
    case response.status
    when 200 then found(JSON.parse(response.body))
    when 404 then nobody_found?(response.body) ? NotFound.new : unexpected(404)
    when 504 then unobtainable(EdmException::TIMEOUT, 504)
    else unexpected(response.status)
    end
  end

  def nobody_found?(body)
    parsed = JSON.parse(body)
    errors = parsed['errors'] if parsed.is_a?(Hash)
    errors.is_a?(Array) && errors.any? { |error| error.is_a?(Hash) && error['code'] == NOBODY_FOUND }
  rescue JSON::ParserError
    false
  end

  # A person admitted nowhere this year holds no student status. A `data` that
  # does not say who is admitted where is no answer, whichever distribution is
  # served: the attestation is the registry's word on that same `data`.
  def found(parsed)
    data = parsed['data'] if parsed.is_a?(Hash)
    return unobtainable(EdmException::QUERY, :unreadable) unless StudentStatus.readable?(data)
    return NotFound.new if data['admissions'].empty?

    Found.new(JSON.generate(data))
  end

  # The link comes from the registry's answer and France follows it: only to
  # the host France called, over HTTPS, and never with the token — the link
  # is its own credential. Nor its address in the log, for the same reason.
  def with_attestation(found, parsed)
    link = parsed.dig('links', 'attestation_pdf') if parsed['links'].is_a?(Hash)
    return unobtainable(EdmException::QUERY, :no_attestation) if link.blank?
    return unobtainable(EdmException::QUERY, :foreign_attestation_link) unless trusted?(link)

    pdf = download(URI.parse(link).request_uri)
    pdf.is_a?(Unobtainable) ? pdf : found.with(attestation: pdf)
  end

  # Compared on the parsed host and port, never as a prefix of a string: a
  # prefix lets `https://staging.particulier.api.gouv.fr.example.org` through.
  def trusted?(link)
    uri = URI.parse(link)
    expected = URI.parse(Settings.api_particulier_url)
    uri.is_a?(URI::HTTPS) && uri.host.to_s.casecmp?(expected.host.to_s) && uri.port == expected.port
  rescue URI::InvalidURIError
    false
  end

  # Read as it arrives and abandoned beyond the limit, so that an oversized
  # body is never held whole, nor a slow one received past `TIMEOUT`: the
  # deadline is checked at each chunk, the adapter's own timeout bounding the
  # wait for the next one. Only the path and query of the link are taken, on
  # the host France is configured to call. No redirection is followed, Faraday
  # following none without a middleware.
  def download(path)
    received = +''
    receive = receiver(received, monotonic + TIMEOUT)
    response = attestation_connection.get(path) { |request| request.options.on_data = receive }
    attestation_of(response.status, received.b)
  end

  def receiver(received, deadline)
    proc do |chunk, size|
      raise AttestationTooLarge if size > MAX_ATTESTATION_SIZE
      raise Faraday::TimeoutError if monotonic > deadline

      received << chunk
    end
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def attestation_of(status, bytes)
    return unobtainable(EdmException::QUERY, "attestation #{status}") unless status == 200
    return unobtainable(EdmException::QUERY, :attestation_not_pdf) unless bytes.start_with?('%PDF-')

    bytes
  end

  # A refused token stops every student status at once: the operator's to fix.
  def unexpected(status)
    if status.in?([401, 403])
      Rails.logger.error(LogLine.t('clients.api_particulier.unauthorized', status:))
      return Unobtainable.new(EdmException::QUERY)
    end

    unobtainable(EdmException::QUERY, status)
  end

  # The cause alone: the body may name the person.
  def unobtainable(exception, cause)
    Rails.logger.warn(LogLine.t('clients.api_particulier.unobtainable', code: exception.code, cause:))
    Unobtainable.new(exception)
  end

  def connection
    @connection ||= Faraday.new(url: Settings.api_particulier_url) do |builder|
      builder.request :authorization, 'Bearer', -> { Settings.api_particulier_token }
      bounded(builder)
    end
  end

  def attestation_connection
    @attestation_connection ||= Faraday.new(url: Settings.api_particulier_url) { |builder| bounded(builder) }
  end

  def bounded(builder)
    builder.options.timeout = TIMEOUT
    builder.options.open_timeout = TIMEOUT
    builder.adapter :net_http
  end
end
