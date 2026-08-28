# Writes the exchange log of chapter 4.8.
#
# Injected by keyword like `Clock` and `UuidGenerator`, so a spec can hand in a
# double and assert on what would have been written.
#
# Nothing here decides what an exchange does; it only records that it happened.
# A failure to write is therefore never caught: a trace the regulation requires,
# silently missing, is worse than a request that fails loudly.
class AuditTrail
  RECEIVED_EVENTS = {
    EbmsAction::EXECUTE_QUERY_REQUEST => 'request_received',
    EbmsAction::EXECUTE_QUERY_RESPONSE => 'response_received',
    EbmsAction::EXCEPTION_RESPONSE => 'error_received',
  }.freeze

  def request_sent(exchange:, requester:, provider:, beneficiary:, evidence_type:, request_id:, message_id:, first_part:)
    record(
      'request_sent',
      ebms_action: EbmsAction::EXECUTE_QUERY_REQUEST,
      **borne_by(exchange),
      evidence_type_id: evidence_type&.id,
      request_id:,
      message_id:,
      **authorities(requesting: requester, providing: provider),
      **AuditEvent.subject(beneficiary),
      **circulated(first_part),
    )
  end

  # The refusals that never reach the gateway: an unknown procedure, an invalid
  # token, a directory that would not answer. Article 17 does not reach these —
  # it covers the request, the response, an error report actually sent, and the
  # eDelivery events — and neither does Domibus, which sees no message at all.
  # Recording them is this deployment's own decision: without it, a caller turned
  # away leaves no trace anywhere.
  def request_refused(requester_id:, procedure_code:, country_code:, reason:, exchange: nil)
    record(
      'request_refused',
      conversation_id: exchange&.conversation_id,
      exchange_id: exchange&.exchange_id,
      evidence_requester_id: requester_id,
      procedure_code:,
      country_code:,
      detail: reason,
    )
  end

  # An envelope the parser refused, which leaves only what the gateway itself
  # named: no header, therefore no exchange, no action and no part. The bytes are
  # the WS plugin's answer and not the correspondent's message, so they do not
  # belong in `regrep_body`, which holds the RegRep document as it circulated.
  #
  # `message_id` is what the line is worth: it is the way into the *Message Log*
  # of the console, where the protocol layer kept what this one could not.
  def message_unreadable(message_id:, reason:)
    record('message_unreadable', message_id:, detail: reason)
  end

  # A message whose action no handler claims. Its header still reads, so it says
  # as much of itself as any arrival does. What it cannot say is the country: the
  # parser refuses to make a body out of an action it cannot name, and a country
  # is only ever read from an agent's address inside one.
  def message_unhandled(message:, message_id:)
    record(
      'message_unhandled',
      **arrived(message, message_id),
      detail: I18n.t('lib.audit_trail.unhandled_action', action: message.action),
    )
  end

  # An answer France built and failed to hand to its own gateway. Nothing
  # circulated, so there is no message identifier and no evidence digest — that
  # digest answers whether a document is the one that went through, and none
  # did. What the line is for is the RegRep body: the gateway never took it, and
  # no other place holds it.
  def answer_not_sent(reason:, exception: nil, **answer)
    record(
      'answer_not_sent',
      ebms_action: exception ? EbmsAction::EXCEPTION_RESPONSE : EbmsAction::EXECUTE_QUERY_RESPONSE,
      edm_error_code: exception&.code,
      detail: reason,
      **answered(**answer),
    )
  end

  # Recorded before the message is dispatched, and not inside the handler that
  # deals with it: a request too malformed to answer, or a response naming an
  # exchange we never opened, must be logged all the same.
  def message_received(message:, message_id:)
    record(
      RECEIVED_EVENTS.fetch(message.action),
      **arrived(message, message_id),
      **(readable(:body) { received_body(message) } || {}),
    )
  end

  # Chapter 4.8's response table asks for the evidence identifier from the
  # requester and from the data service alike: what `response_correlation` reads
  # off an arriving response, France writes here of the one it sends. Both
  # columns come off the one value a deferral leaves nil, so an answer carrying
  # no document names none.
  def response_sent(evidence:, **answer)
    record('response_sent', ebms_action: EbmsAction::EXECUTE_QUERY_RESPONSE,
      evidence_identifier: evidence&.identifier, **answered(**answer),
      **evidence_fingerprint(evidence&.part))
  end

  # `detail` names the rule the refused request broke, so that the journal says
  # what the correspondent was told and not merely that they were told
  # something.
  def error_sent(exception:, **answer)
    record('error_sent', ebms_action: EbmsAction::EXCEPTION_RESPONSE,
      edm_error_code: exception.code, detail: exception.detail, **answered(**answer))
  end

  # What a response was turned away for — the two grounds chapter 4.4 names,
  # and the reservation this deployment adds so that one of them holds. The
  # arrival has its own line already — `IncomingMessage::Process` journals
  # before it dispatches — and this one says what became of it, so that an
  # exchange left waiting can be accounted for later.
  def response_refused(exchange:, reason:)
    record(
      'response_refused',
      **borne_by(exchange),
      request_id: exchange.request_id,
      detail: reason,
    )
  end

  def evidence_delivered(exchange:, evidence:)
    record(
      'evidence_delivered',
      **borne_by(exchange),
      **evidence_fingerprint(evidence),
    )
  end

  private

  # What a message that did arrive says of itself, before anything is made of
  # its body: the action, the two identifiers of chapter 4.4, and the first MIME
  # part — the last read by position, so an action no handler claims carries one
  # just as a request does.
  #
  # The part gets its own reading, and not one of `received_body`'s fields: a
  # body Nokogiri refuses is exactly the one whose bytes an auditor needs, and
  # the chapter asks for them whether or not anything could be made of them.
  def arrived(message, message_id)
    {
      ebms_action: message.action,
      conversation_id: message.conversation_id,
      exchange_id: message.exchange_id,
      message_id:,
      **circulated(readable(:regrep_body) { message.first_part }),
    }
  end

  # Both identifiers of chapter 4.4, and never one alone: the exchange's is what
  # joins these rows to the exchange they belong to, and the conversation's is
  # what gathers the exchanges of one user's session — what chapter 4.7 gives
  # the `ConversationId` for: tracking a user's interactions, and troubleshooting.
  def borne_by(exchange)
    {
      conversation_id: exchange.conversation_id,
      exchange_id: exchange.exchange_id,
      procedure_code: exchange.procedure_code,
      country_code: exchange.country_code,
      evidence_requester_id: exchange.evidence_requester_id,
    }
  end

  # What the two answers have in common; each names its own event rather than
  # leaving the log to infer it from an argument that happens to be nil.
  def answered(message:, requester:, provider:, request_id:, response_id:, message_id:, first_part:)
    {
      conversation_id: message.conversation_id,
      exchange_id: message.exchange_id,
      message_id:,
      request_id:,
      response_id:,
      # Where France answers, the country the answer goes to is the one the
      # request named — `R-EDM-REQ-C073` requiring it on the agent classified
      # `ER`. Our own response carries no address for that agent: the TDD ask
      # for one on the party answering, not on the party answered.
      country_code: requester&.address&.country,
      **authorities(requesting: requester, providing: provider),
      **circulated(first_part),
    }
  end

  # Chapter 4.8, in both its tables: « MIME type and full content of first MIME
  # part ». Written from one value so that a part read only halfway writes
  # neither column rather than a type nothing backs.
  def circulated(part)
    return {} if part.nil?

    { regrep_mime_type: part.mime_type, regrep_body: part.content }
  end

  def record(event_type, **attributes)
    AuditEvent.create!(event_type:, occurred_at: Time.current, **attributes)
  end

  def received_body(message)
    case message.action
    when EbmsAction::EXECUTE_QUERY_REQUEST then received_request(message.body)
    when EbmsAction::EXECUTE_QUERY_RESPONSE then received_response(message)
    when EbmsAction::EXCEPTION_RESPONSE then received_error(message.body)
    else {}
    end
  end

  # Field by field, and not around the whole hash: a literal evaluates every
  # value before it builds anything, so one unreadable field would discard the
  # ones already read — and those are exactly what an auditor has left.
  def received_request(request)
    {
      request_id: readable(:request_id) { request.request_id },
      procedure_code: readable(:procedure_code) { request.procedure_code },
      evidence_type_id: readable(:evidence_type_id) { request.evidence_type.id },
      **requesting_party(request),
      **providing_authority(french_provider),
      **(readable(:evidence_subject) { AuditEvent.subject(request.beneficiary) } || {}),
    }
  end

  # `R-EDM-REQ-C073` requires an address on the agent classified `ER`, and only
  # the country within it: that is where a received request names the country
  # asking, and the only place it does.
  def requesting_party(request)
    requester = readable(:requesting_authority) { request.requester }
    return {} if requester.nil?

    { country_code: requester.address.country, **requesting_authority(requester) }
  end

  # Chapter 4.8 asks the response flow for both parties, the response identifier
  # and the evidence identifier; the country comes from the providing agent,
  # which is also the party that answered.
  def received_response(message)
    provider = readable(:providing_authority) { message.body.provider }

    {
      **response_correlation(message),
      country_code: provider&.address&.country,
      detail: readable(:business_rules) { broken_rules(message.body) },
      **authorities(requesting: readable(:requesting_authority) { message.body.requester }, providing: provider),
      **evidence_fingerprint(readable(:evidence) { carried_evidence(message) }),
    }
  end

  # The rules of chapter 4.6 the arriving response breaks, named as the outgoing
  # side names the one a refusal applies — and nothing is refused over them, so
  # this column is the only place the departure is ever read. Empty when the
  # response conforms; read through `readable` like every other field, a body
  # too malformed to parse costing the line no field that was read before it.
  def broken_rules(response) = response.violations.map(&:sentence).join(' ').presence

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
  def carried_evidence(message)
    message.evidence if message.carries_evidence?
  end

  # The three identifiers chapter 4.8 asks the response flow for: the request
  # answered, the response itself, and the evidence it carries.
  def response_correlation(message)
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
  def received_error(error)
    { request_id: readable(:request_id) { error.request_id }, edm_error_code: readable(:edm_error_code) { error.code },
      country_code: readable(:country_code) { error.provider_country }, detail: readable(:detail) { error.message },
      preview_location: readable(:preview_location) { error.declared_preview_location } }
  end

  def authorities(requesting:, providing:)
    requesting_authority(requesting).merge(providing_authority(providing))
  end

  def requesting_authority(agent)
    { requesting_authority_id: agent&.ebms_identity&.id, requesting_authority_scheme: agent&.ebms_identity&.type_id }
  end

  def providing_authority(agent)
    { providing_authority_id: agent&.ebms_identity&.id, providing_authority_scheme: agent&.ebms_identity&.type_id }
  end

  # Of the evidence as this application holds it, and deliberately not of what
  # the gateway signed: `ds:DigestValue` covers the AS4 payload part as
  # transmitted — MIME framing, and compression on the legs that enable it — so
  # the two never coincide. The route to that signature is `message_id`, which
  # chapter 4.8 traces. This digest answers the other question: whether a
  # document produced later is the one that went through.
  # `evidence_content_id` is the other half of the row chapter 4.8 asks the
  # response flow for: « for evidence content referenced using
  # `rim:RepositoryItemRef` elements, MIME type and MIME content identifier ».
  # Its §4 walks the non-repudiation chain through both at once — from the
  # response identifier one finds the message identifier *and* the MIME content
  # identifier the evidence was packaged in, and the message identifier is what
  # then yields the signed metadata.
  #
  # Written from the one part, so that an answer carrying no document names
  # neither type, nor reference, nor digest, rather than a row asserting a third
  # of what the chapter asks for. That the three are all present the moment the
  # content is comes from the two places a part is built — `payload_part`
  # refuses a declaration without an `href`, and the outgoing side mints the
  # reference before it fills the attachment.
  def evidence_fingerprint(part)
    return {} if part.nil? || part.content.blank?

    {
      evidence_digest: Digest::SHA256.hexdigest(part.content),
      evidence_mime_type: part.mime_type,
      evidence_content_id: part.content_id,
    }
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

  def french_provider = EvidenceProvider.french(**Settings.french_provider_identity)
end
