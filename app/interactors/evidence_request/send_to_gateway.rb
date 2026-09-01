module EvidenceRequest
  # Builds the request and hands it to Domibus.
  class SendToGateway < ApplicationInteractor
    def call
      exchange = context.exchange

      # Before the submission and not after: chapter 4.4 correlates a response to
      # its request by this identifier, and the answer can come back before
      # `submit` has returned.
      exchange.update!(request_id: body.request_id)

      journal(submit(exchange))
    # `UnreadableMessageError` as well as `Faraday::Error`: the gateway can
    # answer 200 with a body we cannot read, and from the caller's point of view
    # that is the same problem — the gateway — not a fault of theirs.
    rescue Faraday::Error, UnreadableMessageError => e
      fail_exchange(exchange, :gateway_refused, e.message)
    end

    private

    # The gateway names the message it accepted, and that name is the only way
    # back to the `ds:SignedInfo` it signed — the non-repudiation chapter 4.8
    # traces from an evidence identifier. Kept, therefore, and not discarded.
    def submit(exchange)
      submitted = context.gateway.submit(envelope.render)
      exchange.sent!

      submitted.message_id
    # The builder validates nothing on construction: the `validate!` calls sit
    # in the private methods `evidence_request.xml.erb` interpolates, so a party
    # no message can carry only raises at `envelope.render` — here, and before
    # `sent!`. Unrescued it leaves the exchange in `IN_PROGRESS`, where the
    # expiry sweep of chapter 4.4 writes it `EDM:ERR:0005`: a code chapter 4.5.3
    # gives to a server whose own processing timed out, imputed to a
    # correspondent no message ever reached.
    #
    # Rescued on this method and not on `call`, whose body also holds `journal`:
    # the same error raised while journalling would abandon an exchange the
    # gateway has actually accepted, and `SettleExchange` would then refuse the
    # correspondent's real answer as `already_settled`.
    rescue ConfigurationError => e
      fail_exchange(exchange, :invalid_configuration,
        I18n.t('interactors.evidence_request.send_to_gateway.invalid_configuration', error: e.message))
    end

    def journal(message_id)
      context.audit_trail.request_sent(
        exchange: context.exchange,
        requester: context.requester,
        provider: context.provider,
        beneficiary: context.beneficiary,
        evidence_type: context.evidence_type,
        request_id: body.request_id,
        message_id:,
        first_part: envelope.first_part,
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

    # Memoised, and the builder rather than its render: the journal reads back
    # the very part that was submitted.
    def envelope
      @envelope ||= build_envelope
    end

    def build_envelope
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
      )
    end
  end
end
