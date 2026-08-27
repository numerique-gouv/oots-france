module EvidenceProvision
  # Answers a request another member state addressed to France.
  #
  # France holds one document today: the PDF it returns for procedure `00`, the
  # OOTS system check. Procedure `R1` is answered with a deferral instead, so
  # that the announcement of chapter 4.5.2 is produced somewhere. Every other
  # procedure is refused with `EDM:ERR:0004`, the expected behaviour as long as
  # no real provider is connected — both the dedicated procedure and the sample
  # evidence are stubs, tracked as OOTS-82.
  class AnswerRequest < ApplicationInteractor
    EVIDENCE_PATH = 'assets/drapeau.pdf'.freeze

    # Chapter 4.4 states this duty in prose and numbers no rule for it, so the
    # detail names the chapter where every other one names a rule.
    REPLAYED_IDENTIFIER = 'TDD 4.4: request identifier already used'.freeze

    # The two identifiers the ebMS header carries, each under the FATAL rule
    # that fixes its shape, and named as the rule's own context names it. Both
    # assertions are made of the document and of no party, so they bind whoever
    # emits — a value a correspondent chose is ours the moment we sign it again.
    #
    # Ordered as the header presents them, so a request malforming both is
    # refused on the conversation and a reader of the journal knows which.
    UUID_RULES = {
      conversation_id: { rule: 'R-EDM-ebMS-017', element: 'eb:ConversationId' },
      exchange_id: { rule: 'R-EDM-ebMS-037', element: 'ExchangeId' },
    }.freeze

    # What France answered, carried rather than left behind in instance
    # variables: the log needs to know which of the three answers went out, and
    # the envelope alone no longer says. It holds the envelope's builder, which
    # is what both `submit` and the journal read — the one rendering it twice
    # would mint a second message identifier.
    #
    # Exactly one of `exception`, `evidence` and `available_at` is set — refusal,
    # document, announcement — and the two others are nil. Nothing enforces it
    # but the three constructors below, which is what lets `journal` and `settle`
    # tell the three apart on two questions rather than three.
    Answer = Data.define(:envelope, :identifier, :exception, :evidence, :available_at)

    def call
      reject_unless_identifiers_are_uuids

      # Outside the rescue, because a request whose requester cannot be read
      # cannot be answered at all: the response would have no final recipient.
      # The request identifier, read inside it, is the opposite case.
      @requester = request.requester

      answer = chosen_or_invalid
      envelope = answer.envelope.render

      journal(answer, submit(answer, envelope))
    end

    private

    attr_reader :requester, :request_id

    # The one departure that would otherwise vanish whole: France has built an
    # answer, the gateway has not taken it, and nothing else holds the document
    # — `Exchange` records the failure but carries no message.
    #
    # The exception is re-raised unchanged, so `IncomingMessage::Process` settles
    # the exchange either way. Only one of the two then reaches what GoodJob
    # records: that interactor re-raises a `Faraday::Error`, where an
    # `UnreadableMessageError` ends in its `give_up`, which logs and stops. This
    # row is the only durable trace of the second case, the application log
    # rotating on its own schedule.
    #
    # The envelope is rendered by the caller and not here: what this rescue
    # means is that the gateway did not take our answer, and a body that could
    # not be built in the first place is another matter.
    def submit(answer, envelope)
      context.gateway.submit(envelope).message_id
    rescue Faraday::Error, UnreadableMessageError => e
      context.audit_trail.answer_not_sent(**answered(answer, nil), exception: answer.exception, reason: e.message)
      raise
    end

    def journal(answer, message_id)
      shared = answered(answer, message_id)

      if answer.exception
        context.audit_trail.error_sent(**shared, exception: answer.exception)
      else
        context.audit_trail.response_sent(**shared, evidence: answer.evidence)
      end

      settle(answer)
    end

    # What both answers record of the message that went out, the first MIME part
    # chapter 4.8 asks for included — read from the envelope that carried it, so
    # the log holds what was submitted and not a second rendering of it.
    def answered(answer, message_id)
      {
        message: context.message, requester:, provider: french_provider,
        request_id:, message_id:, response_id: answer.identifier,
        first_part: answer.envelope.first_part,
      }
    end

    # The exchange France opened on receiving the request reaches its end here
    # once an answer has gone out: answering is the whole of what this side does.
    # A submission that never got through is settled by
    # `IncomingMessage::Process`, which sees the failure come back up.
    def settle(answer)
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

    # The row `IncomingMessage::OpenExchange` wrote on receiving this request —
    # or none, where that interactor adopted a row of the other direction, which
    # it matches on the identifier alone.
    #
    # `defined?` and not `||=`: nil is a legitimate answer here, and `||=` would
    # ask the database again every time it is read.
    def exchange
      return @exchange if defined?(@exchange)

      @exchange = Exchange.find_by(exchange_id: context.message.exchange_id, incoming: true)
    end

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
    # demands of a response omitting the attribute, and of no other.
    def chosen_or_invalid
      @request_id = request.request_id
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

    # `wrap` reuses both identifiers of the request in the envelope France signs,
    # so a malformed one goes back out under our own signature and breaks
    # `R-EDM-ebMS-017` or `-037` on our side, where it broke them on the
    # correspondent's.
    #
    # Called from `call`, and deliberately not from `chosen_answer` where the two
    # rejections below live: theirs becomes an error response, which `wrap` would
    # dress in the very identifiers being refused. Nothing conformant can carry
    # this refusal at all — chapter 4.4 has every message of one exchange reuse
    # its `ExchangeId`, so an exception would repeat the invalid value, and a
    # fresh one would name a different exchange. So nothing goes back, and the
    # journal is the only place the decision can be read afterwards.
    def reject_unless_identifiers_are_uuids
      UUID_RULES.each do |name, rule|
        value = context.message.public_send(name)
        refuse_malformed(rule, value) unless value.to_s.match?(Exchange::UUID)
      end
    end

    # Hung on the exchange `IncomingMessage::OpenExchange` has already opened, so
    # the refusal joins the arrival that `IncomingMessage::Process` journalled
    # before dispatching. The reason names the rule, as `error_sent` does for the
    # refusals that do go back.
    def refuse_malformed(rule, value)
      reason = I18n.t('interactors.evidence_provision.answer_request.malformed_identifier',
        element: rule[:element], value:, rule: rule[:rule])

      context.audit_trail.request_refused(
        requester_id: exchange&.evidence_requester_id, procedure_code: exchange&.procedure_code,
        country_code: exchange&.country_code, reason:, exchange:,
      )

      refuse(rule[:rule], reason)
    end

    # The version travels twice, in the ebMS property and in the body slot, and
    # the two must agree. `request.validate!` pins the body to the same
    # constant, so checking the header against it settles the pair — the
    # coherence OOTS-55 asks for.
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
        identifier: body.document_id, exception: nil, available_at: nil,
        evidence: served_evidence(body, attachment, served))
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

    # The document as the answer carries it: the `cid:` the header declares and
    # the body references through its `rim:RepositoryItemRef`, so the journal
    # records the reference chapter 4.8 asks the data service for rather than a
    # second one minted beside it.
    def served_evidence(body, attachment, served)
      Evidence.new(
        identifier: body.evidence_id,
        part: MimePart.new(mime_type: Attachment::MIME_TYPE, content_id: attachment.identifier, content: served),
      )
    end

    def error_envelope(exception)
      body = ErrorResponseBuilder.new(requester:, exception:, request_id:, uuid: context.uuid)

      Answer.new(envelope: wrap(body, EbmsAction::EXCEPTION_RESPONSE),
        identifier: body.document_id, exception:, evidence: nil, available_at: nil)
    end

    # The corners swap on the way back, and the exchange identifier received is
    # reused: that is what ties both legs of one exchange together.
    #
    # The builder and not its render: `journal` reads the first MIME part back
    # from it, and rendering twice would mint a second message identifier.
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
      )
    end

    def evidence = Rails.root.join(EVIDENCE_PATH).binread

    def french_provider = EvidenceProvider.french(**Settings.french_provider_identity)
  end
end
