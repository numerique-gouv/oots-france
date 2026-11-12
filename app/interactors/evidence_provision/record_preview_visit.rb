module EvidenceProvision
  # A visit to France's preview space. Chapter 4.8 §3.2 asks for the « URL
  # visited », at every visit, identified or not; a first one opens the time
  # the user has; and on the 1.2 line the way back arrives with it, kept from a
  # browser the space has identified (`RememberPreviewReturn`).
  #
  # Where no document matches the user, the visit of a recognised browser is
  # what settles the outcome, there being nothing to decide: the user has read
  # the automated message of chapter 2.1 §3.3, and the second request, if it
  # waits, is answered the empty list of chapter 4.9 §1 — in a job, as
  # `RecordPreviewDecision` does. Nothing is logged as decided: nothing was.
  class RecordPreviewVisit < ApplicationInteractor
    def call
      session = context.preview_session

      audit_trail.preview_visited(session:, location: context.location)
      session.visited! if session.openable?
      recognised(session) if context.identified
    end

    private

    def recognised(session)
      RememberPreviewReturn.call(preview_session: session, return_url: context.return_url,
        return_method: context.return_method)
      AnswerPreviewedRequestJob.perform_later(session.id) if session.unmatched_seen!
    end
  end
end
