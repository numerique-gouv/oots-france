module EvidenceRequest
  # Builds the request and hands it to Domibus.
  class SendToGateway < ApplicationInteractor
    def call
      exchange = context.exchange

      # Before the submission and not after: chapter 4.4 correlates a response to
      # its request by this identifier, and the answer can come back before
      # `submit` has returned.
      exchange.update!(request_id: body.request_id)

      # The gateway names the message it accepted, and that name is the only way
      # back to the `ds:SignedInfo` it signed — the non-repudiation chapter 4.8
      # traces from an evidence identifier. Kept, therefore, and not discarded.
      submitted = context.gateway.submit(envelope)
      exchange.sent!

      journal(submitted.message_id)
    # `UnreadableMessageError` as well as `Faraday::Error`: the gateway can
    # answer 200 with a body we cannot read, and from the caller's point of view
    # that is the same problem — the gateway — not a fault of theirs.
    rescue Faraday::Error, UnreadableMessageError => e
      exchange.failed!(code: nil, description: e.message)
      fail_with_error(:gateway_refused, errors: [e.message])
    end

    private

    def journal(message_id)
      context.audit_trail.request_sent(
        exchange: context.exchange,
        requester: context.requester,
        provider: context.provider,
        beneficiary: context.beneficiary,
        evidence_type: context.evidence_type,
        request_id: body.request_id,
        message_id:,
      )
    end

    def body = @body ||= EvidenceRequestBuilder.new(**request_attributes)

    # `context` is aliased once rather than read nine times: each `context.foo`
    # counts twice against `Metrics/AbcSize`, which this method would otherwise
    # sit one point under.
    def request_attributes
      resolved = context

      {
        requester: resolved.requester, provider: resolved.provider, beneficiary: resolved.beneficiary,
        requirement: resolved.requirement, data_service: resolved.data_service,
        procedure_code: resolved.procedure_code, preview_possible: resolved.preview_possible,
        uuid: resolved.uuid,
      }
    end

    def envelope
      resolved = context
      exchange = resolved.exchange

      OutgoingEnvelopeBuilder.new(
        body:,
        action: EbmsAction::EXECUTE_QUERY_REQUEST,
        recipient: resolved.recipient,
        original_sender: resolved.requester.ebms_identity,
        final_recipient: resolved.provider.ebms_identity,
        conversation_id: exchange.conversation_id,
        exchange_id: exchange.exchange_id,
        uuid: resolved.uuid,
      ).render
    end
  end
end
