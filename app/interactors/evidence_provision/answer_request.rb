module EvidenceProvision
  # Answers a request another member state addressed to France.
  #
  # France holds one document today: the PDF it returns for procedure `00`, the
  # OOTS system check. Every other procedure is refused with `EDM:ERR:0004` —
  # the expected behaviour as long as no real provider is connected. Stub 3 of
  # `docs/reste_à_faire.md`.
  class AnswerRequest < ApplicationInteractor
    EVIDENCE_PATH = 'assets/drapeau.pdf'.freeze

    # What France answered, carried rather than left behind in instance
    # variables: the log needs to know which of the two answers went out, and
    # the envelope alone no longer says.
    Answer = Data.define(:envelope, :identifier, :exception, :evidence)

    def call
      # Outside the rescue, because a request whose requester cannot be read
      # cannot be answered at all: the response would have no final recipient.
      @requester = request.requester
      @request_id = request.request_id

      answer = chosen_or_invalid
      submitted = context.gateway.submit(answer.envelope)

      journal(answer, submitted.message_id)
    end

    private

    attr_reader :requester, :request_id

    def journal(answer, message_id)
      shared = {
        message: context.message, requester:, provider: french_provider,
        request_id:, message_id:, response_id: answer.identifier,
      }

      if answer.exception
        context.audit_trail.error_sent(**shared, exception: answer.exception)
      else
        context.audit_trail.response_sent(**shared, evidence: answer.evidence)
      end

      settle(answer)
    end

    # The exchange France opened on receiving the request reaches its end here,
    # and nowhere else: answering is the whole of what this side does.
    def settle(answer)
      conversation = Conversation.find_by(conversation_id: context.message.conversation_id, incoming: true)
      return unknown_conversation if conversation.nil?

      if answer.exception
        conversation.failed!(code: answer.exception.code, description: answer.exception.message)
      else
        conversation.delivered!
      end
    end

    # `IncomingMessage::Process` en ouvre une avant de dispatcher, donc il y en a
    # toujours une — mais rien dans le code ne l'impose, et une réponse partie
    # sans que son échange soit réglé laisserait un état « en attente » que rien
    # ne viendrait démentir. Dit, comme `SettleConversation` le dit.
    def unknown_conversation
      Rails.logger.warn(
        I18n.t('interactors.evidence_provision.answer_request.unknown_conversation',
          id: context.message.conversation_id),
      )
    end

    def request = context.message.body

    # Readable enough to answer, not enough to serve: `EDM:ERR:0003` rather
    # than silence.
    def chosen_or_invalid
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
      served = evidence
      attachment = attachment_for(served)
      body = SystemCheckResponseBuilder.new(
        requester:, beneficiary: request.beneficiary, evidence_type: request.evidence_type,
        attachment:, request_id:, uuid: context.uuid,
      )

      Answer.new(envelope: wrap(body, EbmsAction::EXECUTE_QUERY_RESPONSE, attachment:),
        identifier: body.document_id, exception: nil, evidence: served)
    end

    def attachment_for(served)
      Attachment.new("cid:#{context.uuid.next}@pdf.oots.fr", Base64.strict_encode64(served))
    end

    def error_envelope(exception)
      body = ErrorResponseBuilder.new(requester:, exception:, request_id:, uuid: context.uuid)

      Answer.new(envelope: wrap(body, EbmsAction::EXCEPTION_RESPONSE),
        identifier: body.document_id, exception:, evidence: nil)
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
