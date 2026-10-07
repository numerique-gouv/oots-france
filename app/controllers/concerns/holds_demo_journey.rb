# The journey every address of the demonstration past the sign-in rests on — the
# identity the authentication attested, and the walk it opened — and the one
# condition they all refuse to render without.
#
# The two are written of a single gesture, in `FranceConnectController`, and
# neither means anything without the other: the journey names the conversation
# the requests of this walk go out under, and the identity is what each of them
# carries. A session holding one alone was written under a shape this code no
# longer reads, and it is sent back to identify itself rather than rendered.
#
# The same validity on the way out as on the way in: what
# `Demo::CompleteIdentification` refused to hold, these pages refuse to show. A
# session written under an earlier shape would otherwise render as a form with
# blank rows, or seal a beneficiary token naming nobody — neither of which any
# layer below would notice.
#
# A journey plays one line and one procedure, from its opening to the next
# identification, and its pages live under their two segments: one opened under
# another line or another procedure is not a page of this walk, and is sent back
# to the screen the line is chosen on.
module HoldsDemoJourney
  extend ActiveSupport::Concern

  included do
    before_action :require_journey
    helper_method :demo_specification
  end

  private

  def identity = @identity ||= ::Demo::UserIdentity.from_session(session[:demo_identity])

  def journey = @journey ||= ::Demo::Journey.from_session(session[:demo_journey])

  def demo_specification = journey.specification

  def require_journey
    redirect_to admin_demo_root_path unless identity&.valid? && journey&.valid? && walked_line?
  end

  def walked_line?
    journey.specification.segment == params[:version] && journey.procedure_code == params[:procedure]
  end
end
