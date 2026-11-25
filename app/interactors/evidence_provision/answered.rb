module EvidenceProvision
  # What both ends of the chain record of the answer that went out, chapter 4.8
  # asking the data service for the first MIME part among it.
  #
  # Shared because two steps record the same message: `SubmitAnswer` when the
  # gateway would not take it, `JournalAnswer` when it did. The part is read
  # from the envelope's builder, so the log holds what was submitted and not a
  # second rendering of it — the part and the ebMS header alike.
  module Answered
    private

    # `context` is aliased once rather than read eight times: each read counts
    # twice against `Metrics/AbcSize`.
    def answered(message_id)
      answering = context
      envelope = answering.answer.envelope

      {
        exchange: answering.exchange,
        message: answering.message,
        requester: answering.requester,
        provider: envelope.provider,
        request_id: answering.request_id,
        message_id:,
        response_id: answering.answer.identifier,
        first_part: envelope.first_part,
        ebms_header: envelope.header,
      }
    end
  end
end
