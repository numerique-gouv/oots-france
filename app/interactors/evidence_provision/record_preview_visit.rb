module EvidenceProvision
  # A visit to France's preview space. Chapter 4.8 §3.2 asks for the « URL
  # visited », at every visit; a first one opens the time the user has; and on
  # the 1.2 line the way back arrives with it (chapter 4.9 v1.2.3 §5) — the
  # last one received before the choice wins, one `WebAddress` cannot open or
  # does not admit is not kept, and the page warns instead (§2, step 13).
  class RecordPreviewVisit < ApplicationInteractor
    # Chapter 4.9 v1.2.3 §5 names the three methods a `returnmethod` may carry.
    RETURN_METHODS = %w[GET POST PUT].freeze

    def call
      session = context.preview_session

      audit_trail.preview_visited(session:, location: context.location)
      session.visited! if session.openable?
      remember_return(session) if session.pending? && session.specification.preview_method_slot?
    end

    private

    def remember_return(session)
      location = context.return_url.to_s
      address = WebAddress.new(location)
      return unless address.openable? && address.admitted?

      method = context.return_method.to_s.upcase
      session.remember_return!(location, method.in?(RETURN_METHODS) ? method : 'GET')
    end
  end
end
