module EvidenceProvision
  # Answers a request another member state addressed to France.
  #
  # France holds one document today: the PDF it returns for procedure `00`, the
  # OOTS system check. Procedure `R1` is answered with a deferral instead, so
  # that the announcement of chapter 4.5.2 is produced somewhere — stub 10.
  # Every other procedure is refused with `EDM:ERR:0004`, the expected behaviour
  # as long as no real provider is connected. Stub 3 of
  # `docs/reste_à_faire.md`.
  class AnswerRequest < ApplicationInteractor
    EVIDENCE_PATH = 'assets/drapeau.pdf'.freeze

    # Chapter 4.4 states this duty in prose and numbers no rule for it, so the
    # detail names the chapter where every other one names a rule.
    REPLAYED_IDENTIFIER = 'TDD 4.4: request identifier already used'.freeze

    # What France answered, carried rather than left behind in instance
    # variables: the log needs to know which of the three answers went out, and
    # the envelope alone no longer says.
    #
    # Exactly one of `exception`, `evidence` and `available_at` is set — refusal,
    # document, announcement — and the two others are nil. Nothing enforces it
    # but the three constructors below, which is what lets `journal` and `settle`
    # tell the three apart on two questions rather than three.
    Answer = Data.define(:envelope, :identifier, :exception, :evidence, :available_at)

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

    # The exchange France opened on receiving the request reaches its end here
    # once an answer has gone out: answering is the whole of what this side does.
    # A submission that never got through is settled by
    # `IncomingMessage::Process`, which sees the failure come back up.
    def settle(answer)
      exchange = Exchange.find_by(exchange_id: context.message.exchange_id, incoming: true)
      return unknown_exchange if exchange.nil?

      if answer.exception
        exchange.failed!(code: answer.exception.code, description: answer.exception.message)
      elsif answer.available_at
        exchange.deferred!(answer.available_at)
      else
        exchange.delivered!
      end
    end

    # `IncomingMessage::Process` opens one before dispatching, so there always
    # is one — but nothing in the code compels it, and an answer gone out with
    # its exchange unsettled would leave a pending state nothing would ever
    # contradict. Said aloud, as `SettleExchange` says it.
    def unknown_exchange
      Rails.logger.warn(
        I18n.t('interactors.evidence_provision.answer_request.unknown_exchange',
          id: context.message.exchange_id),
      )
    end

    def request = context.message.body

    # Readable enough to answer, not enough to serve: `EDM:ERR:0003` rather
    # than silence. The exception is bound and not dropped — what it names is
    # the whole of what a correspondent will learn about their own mistake.
    def chosen_or_invalid
      chosen_answer
    rescue UnreadableMessageError => e
      error_envelope(EdmException::INVALID_REQUEST.with_detail(e.detail))
    end

    def chosen_answer
      reject_unless_expected_version
      request.validate!
      reject_if_already_answered

      return error_envelope(EdmException::OBJECT_NOT_FOUND) unless recognised_procedure?
      return error_envelope(EdmException::UNSUPPORTED_CAPABILITY) unless request.evidence_type.pdf?
      return error_envelope(EdmException::TIMEOUT) if expired?
      return deferred_envelope if request.procedure_code == ProcedureCode::BIRTH_REGISTRATION

      system_check_envelope
    end

    def recognised_procedure?
      request.procedure_code.in?([ProcedureCode::SYSTEM_CHECK, ProcedureCode::BIRTH_REGISTRATION])
    end

    # Chapter 4.4: a Data Service implementing timeout « shall return a timeout
    # exception response … instead of a successful response ». Hence its place
    # last, where the successful answer is chosen: a procedure nobody serves is
    # worth `EDM:ERR:0004` however late the request.
    def expired? = context.message.sent_at < Settings.provider_timeout.ago

    # The version travels twice, in the ebMS property and in the body slot, and
    # the two must agree. `request.validate!` pins the body to the same
    # constant, so checking the header against it settles the pair — the
    # coherence workstream 9 of `docs/reste_à_faire.md` asks for.
    def reject_unless_expected_version
      announced = context.message.specification_id
      return if EdmSpecification.matches?(announced)

      refuse(announced.blank? ? 'R-EDM-ebMS-019' : 'R-EDM-ebMS-038',
        I18n.t('interactors.evidence_provision.answer_request.unexpected_version',
          announced: announced.presence || I18n.t('interactors.evidence_provision.answer_request.unnamed_version'),
          expected: EdmSpecification::IDENTIFIER))
    end

    # Chapter 4.4: « A Data Service MUST reject requests that use identifiers
    # that were used in previously processed requests. » The journal holds the
    # only memory of it — no `Exchange` on the provider side carries a
    # request identifier — and the arriving message has a line there already,
    # `IncomingMessage::Process` journalling before it dispatches.
    def reject_if_already_answered
      return unless AuditEvent.request_already_received?(request_id, except: context.message_id)

      refuse(REPLAYED_IDENTIFIER,
        I18n.t('interactors.evidence_provision.answer_request.request_replayed', id: request_id))
    end

    def refuse(detail, message) = raise(UnreadableMessageError.new(message, detail:))

    def system_check_envelope
      served = evidence
      attachment = attachment_for(served)
      body = SystemCheckResponseBuilder.new(
        requester:, beneficiary: request.beneficiary, evidence_type: request.evidence_type,
        attachment:, request_id:, uuid: context.uuid,
      )

      Answer.new(envelope: wrap(body, EbmsAction::EXECUTE_QUERY_RESPONSE, attachment:),
        identifier: body.document_id, exception: nil, evidence: served, available_at: nil)
    end

    # After the timeout, for the reason `expired?` gives: a correspondent that
    # has already given up has no use for an appointment.
    def deferred_envelope
      body = DeferredResponseBuilder.new(requester:, request_id:, uuid: context.uuid)

      Answer.new(envelope: wrap(body, EbmsAction::EXECUTE_QUERY_RESPONSE),
        identifier: body.document_id, exception: nil, evidence: nil, available_at: body.available_at)
    end

    def attachment_for(served)
      Attachment.new("cid:#{context.uuid.next}@pdf.oots.fr", Base64.strict_encode64(served))
    end

    def error_envelope(exception)
      body = ErrorResponseBuilder.new(requester:, exception:, request_id:, uuid: context.uuid)

      Answer.new(envelope: wrap(body, EbmsAction::EXCEPTION_RESPONSE),
        identifier: body.document_id, exception:, evidence: nil, available_at: nil)
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
