# An `ExceptionResponse` — a correspondent refusing, or asking for a detour.
# The two are not the same: an authorisation error carrying a preview location
# is an instruction to send the user somewhere, not a failure.
class ErrorResponseParser
  include SlotReading

  def initialize(document)
    @response = at(document, '/query:QueryResponse')
    raise UnreadableMessageError, I18n.t('parsers.not_a_query_response') if @response.nil?

    @exception = at(@response, './rs:Exception')
    raise UnreadableMessageError, I18n.t('parsers.error_response.no_exception') if @exception.nil?
  end

  def request_id = attribute(response, 'requestId')

  # The counterpart of `EvidenceResponseParser#provider_country`, on the agent
  # classified `ERRP` and in a slot the TDD make a single value.
  def provider_country
    agent = slot_content('ErrorProvider', response, './sdg:Agent')

    agent_country(agent) if agent
  end

  # R-EDM-ERR-C026 requires the attribute; nothing guarantees the
  # correspondent obeys, so its absence must not raise.
  def code = attribute(exception, 'code')

  def message = attribute(exception, 'message')

  def severity = attribute(exception, 'severity')

  # Read from the severity, which R-EDM-ERR-C022 ties to the preview slot, and
  # not from the exception type, whose prefix is bound in the document and
  # cannot be compared as a string.
  def preview_required? = severity == EdmException::PREVIEW_REQUIRED

  # A foreign correspondent chooses this address and a browser follows it on
  # our own origin: Rails escapes the HTML but does not vet the scheme, and
  # `javascript:…` would be executable there. An unusable address returns nil
  # rather than raising — asking for a preview without saying where is a failed
  # exchange, not an unreadable message.
  ACCEPTED_SCHEMES = %w[http https].freeze

  def preview_location
    location = slot_text('PreviewLocation', exception)

    location if usable?(location)
  end

  def preview_location? = preview_location.present?

  # The code distinguishes the eight errors of the TDD, which the message
  # alone conflates.
  def description = [code, message].compact_blank.join(' : ')

  private

  def usable?(location)
    uri = URI.parse(location)

    uri.scheme.in?(ACCEPTED_SCHEMES) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  attr_reader :response, :exception
end
