module EvidenceProvision
  # A visit to France's preview space. Chapter 4.8 §3.2 asks for the « URL
  # visited », at every visit, identified or not; a first one opens the time
  # the user has; and on the 1.2 line the way back arrives with it, kept from a
  # browser the space has recognised (`RememberPreviewReturn`).
  #
  # Where no document matches the user, the visit of a recognised browser is
  # what settles the outcome, there being nothing to decide: the user has read
  # the automated message of chapter 2.1 §3.3, and the second request, if it
  # waits, is answered the empty list of chapter 4.9 §1 — in a job, as
  # `RecordPreviewDecision` does. The journal says how the preview ended,
  # `unmatched`, once: a page read again finds the outcome already settled.
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
      waiting = session.unmatched_seen!
      return if waiting.nil?

      audit_trail.preview_decided(session:, decision: PreviewSession::UNMATCHED)
      AnswerPreviewedRequestJob.perform_later(session.id) if waiting
    end
  end
end
