# Writes the exchange log of chapter 4.8.
#
# Injected by keyword like `Clock` and `UuidGenerator`, so a spec can hand in a
# double and assert on what would have been written.
#
# Nothing here decides what an exchange does; it only records that it happened.
# It reads no envelope either — what an arriving message says of itself is
# `JournalledMessage`'s to work out, and this class writes down what it hands
# over.
#
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
      **AuditEvent.authorities(requesting: requester, providing: provider),
      **AuditEvent.subject(beneficiary),
      **AuditEvent.circulated(first_part),
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
      **JournalledMessage.new(message:, message_id:).arrived,
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
  # `exchange` is the one `IncomingMessage::Process` correlated the message to,
  # and nil where it could correlate none: an arriving response is judged
  # against the version its own request was written in, which is the exchange's
  # and nothing else's.
  def message_received(message:, message_id:, exchange: nil)
    record(RECEIVED_EVENTS.fetch(message.action),
      **JournalledMessage.new(message:, message_id:, exchange:).attributes)
  end

  # Chapter 4.8's response table asks for the evidence identifier from the
  # requester and from the data service alike: what `JournalledMessage` reads off
  # an arriving response, France writes here of the one it sends. Both
  # columns come off the one value a deferral leaves nil, so an answer carrying
  # no document names none.
  def response_sent(evidence:, **answer)
    record('response_sent', ebms_action: EbmsAction::EXECUTE_QUERY_RESPONSE,
      evidence_identifier: evidence&.identifier, **answered(**answer),
      **AuditEvent.fingerprint(evidence&.part))
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
      **AuditEvent.fingerprint(evidence),
    )
  end

  private

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
      **AuditEvent.authorities(requesting: requester, providing: provider),
      **AuditEvent.circulated(first_part),
    }
  end

  def record(event_type, **attributes)
    AuditEvent.create!(event_type:, occurred_at: Time.current, **attributes)
  end
end
