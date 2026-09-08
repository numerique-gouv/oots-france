module EvidenceProvision
  # What both ends of the chain record of the answer that went out, chapter 4.8
  # asking the data service for the first MIME part among it.
  #
  # Shared because two steps record the same message: `SubmitAnswer` when the
  # gateway would not take it, `JournalAnswer` when it did. The part is read
  # from the envelope's builder, so the log holds what was submitted and not a
  # second rendering of it.
  module Answered
    private

    def answered(message_id)
      {
        message: context.message,
        requester: context.requester,
        provider: EvidenceProvider.french(**Settings.french_provider_identity),
        request_id: context.request_id,
        message_id:,
        response_id: context.answer.identifier,
        first_part: context.answer.envelope.first_part,
      }
    end
  end
end
