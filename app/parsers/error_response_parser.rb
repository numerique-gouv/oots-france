# An `ExceptionResponse` — a correspondent refusing, or asking for a detour.
# The two are not the same: an authorisation error carrying a preview location
# is an instruction to send the user somewhere, not a failure.
class ErrorResponseParser
  include SlotReading
  include ErrorEnvelopeConformance
  include ErrorExceptionConformance
  include ErrorAgentConformance
  include ErrorRegRepShapeConformance
  include ErrorWordingConformance

  # A foreign correspondent chooses this address and a browser follows it on
  # our own origin: Rails escapes the HTML but does not vet the scheme, and
  # `javascript:…` would be executable there. An unusable address returns nil
  # rather than raising — asking for a preview without saying where is a failed
  # exchange, not an unreadable message.
  ACCEPTED_SCHEMES = %w[http https].freeze

  # The version this report is read in, settled by `RetrievedMessageParser` from
  # what the message announces of itself: six rules of chapter 4.6 take a
  # different shape on each line, and four exist on the earlier one alone.
  attr_reader :specification

  # Nothing is required here and nothing raises. `IncomingMessage::Process`
  # journals an arrival before it dispatches it, so a refusal falling in this
  # constructor would leave the line of an unreadable report carrying no rule —
  # and that report is the one whose rule an auditor most needs. The readers
  # below raise instead, at the moment something is actually asked of the
  # document, and `Process#give_up` then abandons the exchange.
  def initialize(document, specification: EdmSpecification.preferred)
    @document = document
    @specification = specification
  end

  # The rules of chapter 4.6 a reader settles on the report alone, and the
  # cardinalities chapter 4.5.3 fixes that no FATAL assertion executes. All
  # `FATAL`, and none of them refused, for the reason
  # `EvidenceResponseParser#violations` states: the chapter assigns the duty of
  # validating to nobody, and chapter 4.5.3 opens no error path from a portal
  # back to a provider. Hence `violations` and not `validate!`.
  #
  # `expected` is the version the exchange runs on, which `R-EDM-ERR-C001` is
  # judged against as `R-EDM-RESP-C002` is: a report is held to the line its own
  # request was written in rather than to the one it announces of itself, which
  # is what makes a correspondent's drift visible instead of self-justifying. A
  # report no exchange could be correlated to is judged in its own version,
  # there being no other to hold it to — which is what `nil` here means.
  def violations(expected: nil)
    [
      *envelope_violations(expected || specification),
      *exception_violations,
      *agent_violations,
      *shape_violations,
      *wording_violations,
    ].compact
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

  # The slot as it arrived, unvetted: chapter 4.8 has the requester log the
  # preview location of an error response, and an address we refused to follow
  # is exactly the one a dispute will be about. A log archives, it does not vet.
  #
  # Optional, because `R-EDM-ERR-C022` puts the slot on one severity only: an
  # error that asks for no preview names none, and that is not a defect.
  def declared_preview_location = optional_slot_text('PreviewLocation', exception)

  # The address anything may act on, which is another question: the exchange
  # keeps it, `EvidenceRequestsController` hands it back to the French service
  # provider — which is what sends the user there, this component rendering
  # nothing to one — and the console turns it into an `href`.
  #
  # Nil rather than raising whether the slot is absent or unusable, as the note
  # above says it should be: asking for a preview without saying where is a
  # failed exchange, not an unreadable message.
  def preview_location
    location = declared_preview_location

    location if usable?(location)
  end

  def preview_location? = preview_location.present?

  # The code distinguishes the eight errors of the TDD, which the message
  # alone conflates.
  def description = [code, message].compact_blank.join(' : ')

  private

  attr_reader :document

  # The document element where it is the `query:QueryResponse` chapter 4.5.3
  # describes, and nil where it is anything else. Every context of chapter 4.6
  # but the four that walk the document opens under it, so this is what the
  # conformance modules read the report through: a document whose root is
  # something else opens none of them, and `R-EDM-ERR-S001` is the rule that
  # says so.
  def declared_response = at(document, RESPONSE)

  # What the readers above need, as opposed to what the rules judge: past
  # `violations` the breach has been named, and what is left is a report nothing
  # can be made of. The two messages are the ones the journal already carries.
  def response
    @response ||= declared_response ||
                  raise(UnreadableMessageError, I18n.t('parsers.not_a_query_response'))
  end

  def exception
    @exception ||= at(response, './rs:Exception') ||
                   raise(UnreadableMessageError, I18n.t('parsers.error_response.no_exception'))
  end

  def usable?(location)
    uri = URI.parse(location)

    uri.scheme.in?(ACCEPTED_SCHEMES) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def violation(rule, key, **)
    BusinessRuleViolation.new(rule:, description: I18n.t("parsers.error_response.#{key}", **))
  end

  # What a sentence puts where a value should have been, agreeing with what it
  # names.
  def named(declared, key) = declared.presence || I18n.t("parsers.error_response.#{key}")
end
