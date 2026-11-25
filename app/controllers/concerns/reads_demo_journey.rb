# The identity and the journey the entrance of the page holds, read without
# requiring them: the screens before the sign-in are rendered whether or not a
# walk is under way, and offer to end it when one is.
#
# The same validity as `HoldsDemoJourney#require_journey`, which the pages past
# the sign-in refuse to render without: what those pages would not show, the
# screens before them do not offer to close.
module ReadsDemoJourney
  extend ActiveSupport::Concern
  include DemoIdentityCookie

  included do
    helper_method :demo_sign_out_path
  end

  private

  def identity = @identity ||= demo_identity(demo_entrance)

  def journey = @journey ||= ::Demo::Journey.from_session(session[demo_entrance.journey_key])

  def journey_held? = identity&.valid? && journey&.valid?

  # The address the sign-out submits to is that of the walk held, not that of
  # the page: the return lands on the home of the procedure the address names,
  # and the screens the line and the procedure are chosen on name none.
  def demo_sign_out_path
    return unless journey_held?

    demo_path(:identification, version: journey.specification.segment, procedure: journey.procedure_code)
  end
end
