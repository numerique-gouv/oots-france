module EvidenceProvision
  # The user's choice in France's preview space. Article 17(2) of implementing
  # regulation 2022/1463 logs it; where the second request is already waiting
  # on it, it is answered in a job, the gateway having no place in the time a
  # page takes to answer.
  class RecordPreviewDecision < ApplicationInteractor
    def call
      session = context.preview_session
      waiting = session.decide!(accepted: context.decision == PreviewSession::ACCEPTED)
      return if waiting.nil?

      audit_trail.preview_decided(session:, decision: context.decision)
      AnswerPreviewedRequestJob.perform_later(session.id) if waiting
    end
  end
end
