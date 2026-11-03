module EvidenceProvision
  # The way back of the 1.2 line, which arrives with a visit and nowhere else
  # (chapter 4.9 v1.2.3 §5): kept while the choice is still to make, the last
  # one received winning; one `WebAddress` cannot open or does not admit is
  # not kept, and the page warns instead (§2, step 13).
  #
  # Only ever from a browser the space has identified, or from the visit that
  # left to identify, carried through the departure: a browser that never came
  # back from identifying cannot move it.
  class RememberPreviewReturn < ApplicationInteractor
    def call
      session = context.preview_session
      return unless session.pending? && session.specification.preview_method_slot?

      location = context.return_url.to_s
      return unless kept?(WebAddress.new(location))

      session.remember_return!(location, return_method)
    end

    private

    def kept?(address) = address.openable? && address.admitted?

    def return_method = PreviewSession.return_method(context.return_method) || 'GET'
  end
end
