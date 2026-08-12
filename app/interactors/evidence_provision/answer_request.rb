module EvidenceProvision
  # Answers a request another member state addressed to France.
  #
  # France holds one document today: the PDF it returns for procedure `00`, the
  # OOTS system check. Every other procedure is refused with `EDM:ERR:0004` —
  # the expected behaviour as long as no real provider is connected. Stub 3 of
  # `docs/reste_à_faire.md`.
  class AnswerRequest < ApplicationInteractor
    EVIDENCE_PATH = 'assets/drapeau.pdf'.freeze

    def call
      # Outside the rescue, because a request whose requester cannot be read
      # cannot be answered at all: the response would have no final recipient.
      @requester = request.requester
      @request_id = request.request_id

      context.gateway.submit(answer)
    end

    private

    attr_reader :requester, :request_id

    def request = context.message.body

    # Readable enough to answer, not enough to serve: `EDM:ERR:0003` rather
    # than silence.
    def answer
      chosen_answer
    rescue UnreadableMessageError
      error_envelope(EdmException::INVALID_REQUEST)
    end

    def chosen_answer
      return error_envelope(EdmException::OBJECT_NOT_FOUND) unless request.procedure_code == ProcedureCode::SYSTEM_CHECK
      return error_envelope(EdmException::UNSUPPORTED_CAPABILITY) unless request.evidence_type.pdf?

      system_check_envelope
    end

    def system_check_envelope
      attachment = Attachment.new("cid:#{context.uuid.next}@pdf.oots.fr", Base64.strict_encode64(evidence))
      body = SystemCheckResponseBuilder.new(
        requester:, beneficiary: request.beneficiary, evidence_type: request.evidence_type,
        attachment:, request_id:, uuid: context.uuid,
      )

      wrap(body, EbmsAction::EXECUTE_QUERY_RESPONSE, attachment:)
    end

    def error_envelope(exception)
      body = ErrorResponseBuilder.new(requester:, exception:, request_id:, uuid: context.uuid)

      wrap(body, EbmsAction::EXCEPTION_RESPONSE)
    end

    # The corners swap on the way back, and the exchange identifier received is
    # reused: that is what ties both legs of one exchange together.
    def wrap(body, action, attachment: EmptyAttachment.new)
      OutgoingEnvelopeBuilder.new(
        body:,
        attachment:,
        action:,
        recipient: context.message.sender,
        original_sender: french_provider.ebms_identity,
        final_recipient: requester.ebms_identity,
        conversation_id: context.message.conversation_id,
        exchange_id: context.message.exchange_id,
        uuid: context.uuid,
      ).render
    end

    def evidence = Rails.root.join(EVIDENCE_PATH).binread

    def french_provider = EvidenceProvider.french(**Settings.french_provider_identity)
  end
end
