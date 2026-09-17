# What a retrieved message says of itself, as the columns of chapter 4.8.
#
# It reads and nothing else: no line is written here, and a spec can assert what
# was understood of an envelope without an `AuditEvent` existing. `AuditTrail`
# records what this hands it.
#
# Every field is read under `readable`, one by one and never around the whole
# hash: a literal evaluates every value before it builds anything, so one
# unreadable field would discard the ones already read — and those are exactly
# what an auditor has left.
class JournalledMessage
  ACTIONS = {
    EbmsAction::EXECUTE_QUERY_REQUEST => :received_request,
    EbmsAction::EXECUTE_QUERY_RESPONSE => :received_response,
    EbmsAction::EXCEPTION_RESPONSE => :received_error,
  }.freeze

  # `exchange` is the one `IncomingMessage::Process` correlated the message to,
  # and nil where it could correlate none: an arriving response is judged
  # against the version its own request was written in, which is the exchange's
  # and nothing else's.
  def initialize(message:, message_id:, exchange: nil)
    @message = message
    @message_id = message_id
    @exchange = exchange
  end

  def attributes = arrived.merge(readable(:body) { body } || {})

  # What a message that did arrive says of itself, before anything is made of
  # its body: the action, the two identifiers of chapter 4.4, and the first MIME
  # part — the last read by position, so an action no handler claims carries one
  # just as a request does.
  #
  # The part gets its own reading, and not one of the body's fields: a body
  # Nokogiri refuses is exactly the one whose bytes an auditor needs, and the
  # chapter asks for them whether or not anything could be made of them.
  def arrived
    {
      ebms_action: message.action,
      conversation_id: message.conversation_id,
      exchange_id: message.exchange_id,
      message_id:,
      **AuditEvent.circulated(readable(:regrep_body) { message.first_part }),
    }
  end

  private

  attr_reader :message, :message_id, :exchange

  def body = ACTIONS.key?(message.action) ? send(ACTIONS.fetch(message.action)) : {}

  def received_request
    request = message.body

    {
      request_id: readable(:request_id) { request.request_id },
      procedure_code: readable(:procedure_code) { request.procedure_code },
      evidence_type_id: readable(:evidence_type_id) { request.evidence_type.id },
      **requesting_party(request),
      **AuditEvent.providing_authority(french_provider),
      **(readable(:evidence_subject) { AuditEvent.subject(request.beneficiary) } || {}),
    }
  end

  # `R-EDM-REQ-C073` requires an address on the agent classified `ER`, and only
  # the country within it: that is where a received request names the country
  # asking, and the only place it does.
  def requesting_party(request)
    requester = readable(:requesting_authority) { request.requester }
    return {} if requester.nil?

    { country_code: requester.address.country, **AuditEvent.requesting_authority(requester) }
  end

  # Chapter 4.8 asks the response flow for both parties, the response identifier
  # and the evidence identifier.
  #
  # The subject is what its tables do not ask for and the sentence opening its
  # §3.2 does: « the information included in the evidence response, with the
  # exception of the evidence itself, must be logged ». Chapter 4.5.2 makes
  # `sdg:IsAbout` the subject the provider confirms having matched, where
  # `received_request` records the one that was asked for — the two are allowed
  # to differ, and that gap is what an auditor came for.
  def received_response
    {
      **response_correlation,
      **answering_parties,
      detail: readable(:business_rules) { broken_rules },
      **AuditEvent.fingerprint(readable(:evidence) { carried_evidence }),
      **(readable(:evidence_subject) { AuditEvent.subject(message.body.evidence_subject) } || {}),
    }
  end

  # The counterpart of `requesting_party` on the way in: both parties again, and
  # the country, which comes from the providing agent — the party that answered.
  #
  # Each reading guarded on its own, though all of them are of the RegRep
  # document: `message.body` itself raises on an envelope Nokogiri refuses, so an
  # unguarded one would cost the line every field already read — the evidence
  # fingerprint among them, which is read from the envelope and owes nothing to
  # that document.
  def answering_parties
    provider = readable(:providing_authority) { message.body.provider }

    {
      country_code: provider&.address&.country,
      **AuditEvent.authorities(requesting: readable(:requesting_authority) { message.body.requester },
        providing: provider),
    }
  end

  # The three identifiers chapter 4.8 asks the response flow for: the request
  # answered, the response itself, and the evidence it carries.
  def response_correlation
    {
      request_id: readable(:request_id) { message.body.request_id },
      response_id: readable(:response_id) { message.body.response_id },
      evidence_identifier: readable(:evidence_identifier) { message.body.evidence_identifier },
    }
  end

  # Chapter 4.8 lists « Preview Location » among what an evidence requester logs
  # of an error response, next to the error report itself. Recorded as declared
  # and not as `preview_location` vets it: the address France refused to follow
  # is the one an auditor will ask about, and the scheme is vetted where it
  # decides something — the value the exchange keeps and hands back to the
  # French service provider, and the one the console turns into an `href`.
  #
  # `detail` holds two things here, the chapter's table leaving one column for
  # either: what the correspondent said, which is what a human reads to find out
  # what happened, and what the report breaks saying it, which is what says the
  # correspondent drifted. The message comes first.
  #
  def received_error
    error = message.body

    {
      request_id: readable(:request_id) { error.request_id },
      edm_error_code: readable(:edm_error_code) { error.code },
      country_code: readable(:country_code) { error.provider_country },
      detail: refusal_detail(error),
      preview_location: readable(:preview_location) { error.declared_preview_location },
    }
  end

  # The two are read apart and joined afterwards, for the reason this class
  # gives field by field: an exception too malformed to say its own message must
  # not cost the line the rules that say so, which is the very case those rules
  # exist for.
  def refusal_detail(error)
    said = [readable(:detail) { error.message }, readable(:business_rules) { broken_rules }]

    said.compact_blank.join(' ').presence
  end

  # What the arriving message breaks, named as the outgoing side names the one a
  # refusal applies — and nothing is refused over them, so this column is the
  # only place the departure is ever read. Empty when the message conforms.
  #
  # What the envelope contradicts in itself comes first, and the rules of chapter
  # 4.6 follow it: chapter 4.7 §2.6.2 says the message is invalid whole, and it
  # is what explains the packaging violations behind it — a body read in the line
  # its header announced breaks the rules of the line its own slot claimed. Which
  # is why the envelope is read here and not the body alone: the two version
  # announcements are only both readable on the envelope.
  def broken_rules
    rules = message.inconsistencies + message.body.violations(expected: exchange&.specification)

    rules.map(&:sentence).join(' ').presence
  end

  # Chapter 4.5.2 lets a conformant response carry no evidence part at all —
  # one announcing the evidence for later, and equally one whose package is
  # empty because nothing matched or the user kept nothing at preview. Looking
  # for a part the envelope never declared would report the ordinary case as
  # unreadable, and the warning `readable` keeps for a message that really is
  # malformed is worth nothing once the ordinary case raises it too.
  #
  # Asked of the header rather than of the status or of the body: a deferral may
  # carry the pieces that *are* available, and a body too malformed to parse is
  # exactly the one whose evidence fingerprint an auditor still needs. Past this
  # guard, a part was announced and could not be read.
  def carried_evidence
    message.evidence if message.carries_evidence?
  end

  # A message we cannot read must still be journalled, so what its body would
  # have added is dropped rather than raised — the trace is worth more than the
  # field.
  #
  # Said aloud all the same, because on the response side nothing else will:
  # `SettleExchange` takes the evidence from the envelope and the requester
  # from the exchange, never from the body, so the two parties chapter 4.8 asks
  # for can go missing from the one row that records them while the exchange
  # succeeds. A degraded row is then at least findable in the logs.
  def readable(field)
    yield
  rescue UnreadableMessageError => e
    Rails.logger.warn(I18n.t('lib.audit_trail.unreadable_field', field:, error: e.message))
    nil
  end

  def french_provider = EvidenceProvider.french
end
