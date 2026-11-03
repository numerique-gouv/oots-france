module EvidenceProvision
  # A visit to France's preview space. Chapter 4.8 §3.2 asks for the « URL
  # visited », at every visit, identified or not; a first one opens the time
  # the user has; and on the 1.2 line the way back arrives with it, kept from a
  # browser the space has identified (`RememberPreviewReturn`).
  class RecordPreviewVisit < ApplicationInteractor
    def call
      session = context.preview_session

      audit_trail.preview_visited(session:, location: context.location)
      session.visited! if session.openable?
      return unless context.identified

      RememberPreviewReturn.call(preview_session: session, return_url: context.return_url,
        return_method: context.return_method)
    end
  end
end
