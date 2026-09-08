module EvidenceProvision
  # Decides which of the three answers goes back, and builds it.
  #
  # The order below is the whole of this step, and it is significant: chapter
  # 4.4 has a data service implementing timeout « return a timeout exception
  # response … instead of a successful response », which puts the deadline last,
  # where the successful answer is chosen — a procedure nobody serves is worth
  # `EDM:ERR:0004` however late the request.
  class ChooseAnswer < ApplicationInteractor
    # The procedures a document is served for, and the document itself: France
    # holds no real evidence, so the same sample answers both. Stub, tracked as
    # OOTS-82.
    SERVED_PROCEDURES = [ProcedureCode::SYSTEM_CHECK, ProcedureCode::STUDY_FINANCING].freeze
    EVIDENCE_PATH = 'assets/drapeau.pdf'.freeze

    # Chapter 4.4 states this duty in prose and numbers no rule for it, so the
    # detail names the chapter where every other one names a rule.
    REPLAYED_IDENTIFIER = 'TDD 4.4: request identifier already used'.freeze

    def call
      # Outside the rescue, because a request whose requester cannot be read
      # cannot be answered at all: the response would have no final recipient.
      # The request identifier, read inside it, is the opposite case.
      context.requester = request.requester

      context.answer = chosen_or_invalid
    end

    private

    def requester = context.requester

    def request_id = context.request_id

    def request = context.message.body

    # Readable enough to answer, not enough to serve: `EDM:ERR:0003` rather
    # than silence. The exception is bound and not dropped — what it names is
    # the whole of what a correspondent will learn about their own mistake.
    #
    # The identifier is read here and not beside the requester, so that
    # `R-EDM-REQ-S004` refusing it leaves `request_id` nil: the answer then
    # carries no `requestId` at all rather than one that would break
    # `R-EDM-ERR-S004`. This is also the only place that can produce that nil,
    # and it produces `INVALID_REQUEST` with it — which is what `R-EDM-ERR-C025`
    # demands of a response omitting the attribute, and of no other. The two
    # facts are one, and do not come apart.
    def chosen_or_invalid
      context.request_id = request.request_id
      chosen_answer
    rescue UnreadableMessageError => e
      refusal(EdmException::INVALID_REQUEST.with_detail(e.detail))
    end

    def chosen_answer
      reject_unless_expected_version
      request.validate!
      reject_if_already_answered

      return refusal(EdmException::OBJECT_NOT_FOUND) unless recognised_procedure?
      return refusal(EdmException::UNSUPPORTED_CAPABILITY) unless request.evidence_type.pdf?
      return refusal(EdmException::TIMEOUT) if expired?
      return deferral if request.procedure_code == ProcedureCode::BIRTH_REGISTRATION

      served
    end

    def recognised_procedure?
      request.procedure_code.in?(SERVED_PROCEDURES) ||
        request.procedure_code == ProcedureCode::BIRTH_REGISTRATION
    end

    # « If a Data Service implements timeout » is the conditional
    # `Settings.timeout_enabled?` answers, chapter 4.4.3 letting a deployment
    # provide none. Read first so that `Settings.provider_timeout` is not
    # evaluated: no duration is configured on that side.
    def expired? = Settings.timeout_enabled? && context.message.sent_at < Settings.provider_timeout.ago

    # The version travels twice, in the ebMS property and in the body slot, and
    # the two must agree. `request.validate!` pins the body to the same
    # constant, so checking the header against it settles the pair — the
    # inconsistency chapter 4.7 requires the receiver to reject.
    def reject_unless_expected_version
      announced = context.message.specification_id
      return if EdmSpecification.matches?(announced)

      refuse(announced.blank? ? 'R-EDM-ebMS-019' : 'R-EDM-ebMS-038',
        I18n.t('interactors.evidence_provision.choose_answer.unexpected_version',
          announced: announced.presence || I18n.t('interactors.evidence_provision.choose_answer.unnamed_version'),
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
        I18n.t('interactors.evidence_provision.choose_answer.request_replayed', id: request_id))
    end

    # Caught by `chosen_or_invalid` above, which turns it into the exception
    # response that goes back.
    def refuse(detail, message) = raise(UnreadableMessageError.new(message, detail:))

    def served
      document = evidence
      attachment = attachment_for(document)
      body = EvidenceResponseBuilder.new(
        requester:, beneficiary: request.beneficiary, evidence_type: request.evidence_type,
        attachment:, request_id:, uuid:,
      )

      Answers::Served.new(envelope: wrap(body, EbmsAction::EXECUTE_QUERY_RESPONSE, attachment:),
        identifier: body.document_id, evidence: served_evidence(body, attachment, document))
    end

    # After the timeout, for the reason `expired?` gives: a correspondent that
    # has already given up has no use for an appointment.
    def deferral
      body = DeferredResponseBuilder.new(requester:, request_id:, uuid:)

      Answers::Deferral.new(envelope: wrap(body, EbmsAction::EXECUTE_QUERY_RESPONSE),
        identifier: body.document_id, available_at: body.available_at)
    end

    def attachment_for(document)
      Attachment.new("cid:#{uuid.next}@pdf.oots.fr", Base64.strict_encode64(document))
    end

    # The document as the answer carries it: the `cid:` the header declares and
    # the body references through its `rim:RepositoryItemRef`, so the journal
    # records the reference chapter 4.8 asks the data service for rather than a
    # second one minted beside it.
    def served_evidence(body, attachment, document)
      Evidence.new(
        identifier: body.evidence_id,
        part: MimePart.new(mime_type: Attachment::MIME_TYPE, content_id: attachment.identifier, content: document),
      )
    end

    def refusal(exception)
      body = ErrorResponseBuilder.new(requester:, exception:, request_id:, uuid:)

      Answers::Refusal.new(envelope: wrap(body, EbmsAction::EXCEPTION_RESPONSE),
        identifier: body.document_id, exception:)
    end

    # The corners swap on the way back, and the exchange identifier received is
    # reused: that is what ties both legs of one exchange together.
    #
    # The builder and not its render: `JournalAnswer` reads the first MIME part
    # back from it, and rendering twice would mint a second message identifier.
    def wrap(body, action, attachment: EmptyAttachment.new)
      OutgoingEnvelopeBuilder.new(
        body:,
        attachment:,
        action:,
        recipient: context.message.sender,
        original_sender: EvidenceProvider.french(**Settings.french_provider_identity).ebms_identity,
        final_recipient: requester.ebms_identity,
        conversation_id: context.message.conversation_id,
        exchange_id: context.message.exchange_id,
        uuid:,
      )
    end

    def evidence = Rails.root.join(EVIDENCE_PATH).binread
  end
end
