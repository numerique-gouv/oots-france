module EvidenceProvision
  # T2 or T3 run out on a preview (chapter 4.4 §4.4.3). What France kept of
  # the user goes; a user who never chose is logged as having left without
  # deciding (article 17(2) of implementing regulation 2022/1463); and a second
  # request left waiting is answered the timeout exception of chapter 4.9 §2,
  # step 14 — here and not in a queued job, so that the row is still there to answer
  # from when the sweep destroys what is past T2 + T3.
  class ExpirePreview < ApplicationInteractor
    def call
      session = context.preview_session
      undecided = session.decision.nil?
      return unless session.expire!

      audit_trail.preview_decided(session:, decision: nil) if undecided
      AnswerAfterPreview.call(preview_session_id: session.id, audit_trail:) if session.second_request.present?
    end
  end
end
