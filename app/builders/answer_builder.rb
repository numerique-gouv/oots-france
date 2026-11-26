# What France sends back to one received request, whatever it decided to
# answer: the body of each kind of answer, and the envelope that carries it to
# the requester. `EvidenceProvision::ChooseAnswer` decides; this assembles.
#
# Apart from the step because the cross-validation specimens
# (`Oots::AnswerSpecimens`) call it too: what they confront with the request is
# then what production sends, where a copy of this assembly would not share
# its defects.
class AnswerBuilder
  # `message` is the `RetrievedMessageParser` of the received request.
  # `request_id` is passed rather than read, because reading it may be what
  # refused the request: an answer to an unreadable identifier carries none.
  def initialize(message:, request_id:, uuid:, clock: Clock.new)
    @message = message
    @request_id = request_id
    @uuid = uuid
    @clock = clock
  end

  # A `clock` in `described` — the instant a preview or a registry fixed —
  # wins over this one, being splatted after it.
  def evidence_response(beneficiary:, evidence_type:, evidence_reference:, **described)
    EvidenceResponseBuilder.new(
      requester:, provider:, beneficiary:, evidence_type:, evidence_reference:, request_id:, specification:, uuid:,
      issuer: issuer(evidence_type), distribution: ServedEvidenceType.distribution_for(evidence_type),
      clock:, **described
    )
  end

  def empty_response = EvidenceResponseBuilder.new(requester:, provider:, request_id:, specification:, clock:, uuid:)

  def deferred_response = DeferredResponseBuilder.new(requester:, provider:, request_id:, specification:, clock:, uuid:)

  def error_response(exception, preview_location: nil)
    ErrorResponseBuilder.new(requester:, exception:, request_id:, preview_location:, specification:, clock:, uuid:)
  end

  # The corners swap on the way back, and the exchange identifier received is
  # reused: that is what ties both legs of one exchange together.
  #
  # Both corners are the request's header swapped, value and `type`, and never
  # read off a body — chapter 4.7 §2.4, `R-ebMS_ebMS-05` to `-08` (FATAL), and
  # the Commission's instruction of 2026-11-26 (OOTS-329), for errors as for
  # responses.
  # Where the request's header names other parties than its body, the answer
  # then breaks `R-ebMS_EDM-RESP-01` to `-04` or `R-ebMS_EDM-ERR-01` to `-04`:
  # no answer can satisfy both sets, its `EvidenceRequester` admitting one agent
  # only, which `R-EDM-REQ_EDM-RESP-13` holds to the request's `ER`.
  def envelope(body, action, attachment: EmptyAttachment.new)
    OutgoingEnvelopeBuilder.new(
      body:,
      attachment:,
      action:,
      recipient: message.sender,
      original_sender: message.final_recipient,
      final_recipient: message.original_sender,
      conversation_id: message.conversation_id,
      exchange_id: message.exchange_id,
      specification:,
      clock:,
      uuid:,
    )
  end

  # The evidence beside an evidence response, under the reference its body
  # gives it and in the format the type is served in.
  def attachment(body, document)
    Attachment.new(body.evidence_reference, Base64.strict_encode64(document),
      mime_type: ServedEvidenceType.distribution_for(body.evidence_type).format)
  end

  private

  attr_reader :message, :request_id, :uuid, :clock

  def request = message.body

  def requester = @requester ||= request.requester

  # The agent the request designates, announced as `EP` by every evidence
  # response — `R-EDM-REQ_EDM-RESP-15` and `-16`. For the second request of a
  # preview, `request` is that second request, whose provider is the one the
  # rules compare.
  def provider = @provider ||= request.provider

  # The version the answer is written in: the one the request was read in.
  # Chapter 4.7 §2.6.2 — « The same SpecificationId value MUST be used
  # consistently in both request and response messages belonging to the same
  # evidence exchange » — and, for the mechanism the slot alone carries, a 2.0
  # response to a 1.2 request would fail at its destination on
  # `R-EDM-RESP-S015`, whose 1.2.5 context is the object of the list and not
  # the package around it.
  #
  # Read off the message and not off an exchange: where the header contradicts
  # the body it is the header that says which line the refusal goes back on,
  # and a request France could not read at all names no exchange to ask.
  def specification = message.specification

  # France issues its test documents itself.
  def issuer(evidence_type) = (StudentStatus.issuer if ServedEvidenceType.student_status?(evidence_type))
end
