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

  def request_sent(conversation:, requester:, provider:, beneficiary:, evidence_type:, request_id:, message_id:)
    record(
      'request_sent',
      ebms_action: EbmsAction::EXECUTE_QUERY_REQUEST,
      conversation_id: conversation.conversation_id,
      procedure_code: conversation.procedure_code,
      country_code: conversation.country_code,
      evidence_requester_id: conversation.evidence_requester_id,
      evidence_type_id: evidence_type&.id,
      request_id:,
      message_id:,
      **authorities(requesting: requester, providing: provider),
      **AuditEvent.subject(beneficiary),
    )
  end

  # The refusals that never reach the gateway: an unknown procedure, an invalid
  # token, a directory that would not answer. Article 17 does not reach these —
  # it covers the request, the response, an error report actually sent, and the
  # eDelivery events — and neither does Domibus, which sees no message at all.
  # Recording them is this deployment's own decision: without it, a caller turned
  # away leaves no trace anywhere.
  def request_refused(requester_id:, procedure_code:, country_code:, reason:, conversation: nil)
    record(
      'request_refused',
      conversation_id: conversation&.conversation_id,
      evidence_requester_id: requester_id,
      procedure_code:,
      country_code:,
      detail: reason,
    )
  end

  # Recorded before the message is dispatched, and not inside the handler that
  # deals with it: a request too malformed to answer, or a response naming a
  # conversation we never opened, must be logged all the same.
  def message_received(message:, message_id:)
    record(
      RECEIVED_EVENTS.fetch(message.action),
      ebms_action: message.action,
      conversation_id: message.conversation_id,
      exchange_id: message.exchange_id,
      message_id:,
      **(readable(:body) { received_body(message) } || {}),
    )
  end

  def response_sent(evidence:, **answer)
    record('response_sent', ebms_action: EbmsAction::EXECUTE_QUERY_RESPONSE,
                            **answered(**answer), **evidence_fingerprint(evidence))
  end

  # `detail` names the rule the refused request broke, so that the journal says
  # what the correspondent was told and not merely that they were told
  # something.
  def error_sent(exception:, **answer)
    record('error_sent', ebms_action: EbmsAction::EXCEPTION_RESPONSE,
      edm_error_code: exception.code, detail: exception.detail, **answered(**answer))
  end

  # What a response was turned away for, chapter 4.4 naming two grounds. The
  # arrival has its own line already — `IncomingMessage::Process` journals
  # before it dispatches — and this one says what became of it, so that an
  # exchange left waiting can be accounted for later.
  def response_refused(conversation:, reason:)
    record(
      'response_refused',
      conversation_id: conversation.conversation_id,
      procedure_code: conversation.procedure_code,
      country_code: conversation.country_code,
      evidence_requester_id: conversation.evidence_requester_id,
      request_id: conversation.request_id,
      detail: reason,
    )
  end

  def evidence_delivered(conversation:, evidence:)
    record(
      'evidence_delivered',
      conversation_id: conversation.conversation_id,
      procedure_code: conversation.procedure_code,
      country_code: conversation.country_code,
      evidence_requester_id: conversation.evidence_requester_id,
      **evidence_fingerprint(evidence),
    )
  end

  private

  # What the two answers have in common; each names its own event rather than
  # leaving the log to infer it from an argument that happens to be nil.
  def answered(message:, requester:, provider:, request_id:, response_id:, message_id:)
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
    }
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
      **authorities(requesting: readable(:requesting_authority) { message.body.requester }, providing: provider),
      **evidence_fingerprint(readable(:evidence_digest) { message.evidence }),
    }
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

  def received_error(error)
    { request_id: readable(:request_id) { error.request_id }, edm_error_code: readable(:edm_error_code) { error.code },
      country_code: readable(:country_code) { error.provider_country }, detail: readable(:detail) { error.message } }
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
  def evidence_fingerprint(evidence)
    return {} if evidence.blank?

    { evidence_digest: Digest::SHA256.hexdigest(evidence), mime_type: RetrievedMessageParser::PDF }
  end

  # A message we cannot read must still be journalled, so what its body would
  # have added is dropped rather than raised — the trace is worth more than the
  # field.
  #
  # Said aloud all the same, because on the response side nothing else will:
  # `SettleConversation` takes the evidence from the envelope and the requester
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
