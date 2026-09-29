module EvidenceProvision
  # The two round trips of chapter 4.9 §2, as `ChooseAnswer` answers them: the
  # first sends the user to France's preview space, the second carries back
  # what the user decided there.
  module PreviewAnswers
    # Step 12 has the data service « validate the link and return an error if
    # validation fails », naming no code and no rule.
    UNKNOWN_PREVIEW = 'TDD 4.9 §2 step 12: PreviewLocation not issued for this exchange, or already answered'.freeze

    private

    # Step 9. The document is produced now, so that what the user previews is
    # byte for byte what the answer will carry (§3), and kept with the
    # identifier and instant that describe it.
    def preview_required
      evidence_id = uuid.next
      instant = clock.now
      message = context.message
      session = PreviewSession.issue(token: uuid.next, conversation_id: message.conversation_id,
        specification: message.specification, first_request: message.raw, evidence_id:,
        exchange_id: previewed_exchange_id, evidence_issued_at: instant, document: preview_document(evidence_id, instant))

      preview_refusal(session.location)
    end

    # The row the request opened, whose identifier France minted on the 1.2 line.
    def previewed_exchange_id = context.exchange&.exchange_id || context.message.exchange_id

    def preview_document(evidence_id, instant)
      EvidenceDocumentBuilder.new(evidence_id:, instant:, evidence_type: request.evidence_type,
        beneficiary: request.beneficiary).render
    end

    def preview_refusal(location)
      exception = EdmException::AUTHORIZATION
      body = ErrorResponseBuilder.new(requester:, exception:, request_id:, preview_location: location,
        specification:, uuid:)

      Answers::PreviewRequired.new(envelope: wrap(body, EbmsAction::EXCEPTION_RESPONSE),
        identifier: body.document_id, location:)
    end

    # Steps 12 to 14 and 26. An address France never issued, or already
    # answered, is refused without echoing it (chapter 1 §7.3); an expired one
    # with the timeout exception step 14 names. The request is otherwise held,
    # and answered as the user decided — or not yet, if they have not.
    #
    # Replayed by `AnswerAfterPreview` once the user decides, or once T3 runs
    # out: the session then already holds this very message.
    def second_exchange
      session = issued_session
      return refusal(EdmException::INVALID_REQUEST.with_detail(UNKNOWN_PREVIEW)) if session.nil?

      context.preview_session = session if session.holds?(context.message_id)
      return refusal(EdmException::TIMEOUT) if session.expired?

      context.preview_session = session
      decided(session, hold(session))
    end

    def issued_session
      found = PreviewSession.find_by(location: request.preview_location)
      found if found&.continued_by?(context.message.exchange_id)
    end

    # The row this request opened or reopened, and none where France answers
    # itself through one gateway and the row is the one its request opened.
    def hold(session)
      answering = context.exchange if context.exchange&.incoming?

      session.hold!(raw: context.message.raw, sent_at: context.message.sent_at, message_id: context.message_id, answering:,
        return_location: request.return_location)
    end

    def decided(session, decision)
      case decision
      when nil then Answers::Withheld.new
      when PreviewSession::ACCEPTED then previewed(session)
      else declined
      end
    end

    # §3: « all and only those pieces of evidence that the user decided to
    # use » — the document kept, described under the identifier and at the
    # instant it was produced with.
    def previewed(session)
      reference = OutgoingEnvelopeBuilder.payload_reference(uuid.next)
      body = previewed_body(session, reference)
      attachment = Attachment.new(reference, session.document)

      Answers::Served.new(envelope: wrap(body, EbmsAction::EXECUTE_QUERY_RESPONSE, attachment:),
        identifier: body.document_id, evidence: served_evidence(body, attachment, session.document_bytes))
    end

    def previewed_body(session, reference)
      first = RetrievedMessageParser.new(session.first_request).body

      EvidenceResponseBuilder.new(
        requester:, beneficiary: first.beneficiary, evidence_type: first.evidence_type, evidence_reference: reference,
        evidence_id: session.evidence_id, request_id:, specification:, uuid:,
        clock: Oots::FrozenClock.new(session.evidence_instant)
      )
    end

    def declined
      body = EvidenceResponseBuilder.new(requester:, request_id:, specification:, uuid:)

      Answers::Declined.new(envelope: wrap(body, EbmsAction::EXECUTE_QUERY_RESPONSE), identifier: body.document_id)
    end
  end
end
