# The identity the demonstration's two remaining pages both rest on, and the
# one condition they both refuse to render without.
#
# The same validity on the way out as on the way in: what
# `Demo::CompleteIdentification` refused to hold, these pages refuse to show. A
# session written under an earlier shape would otherwise render as a form with
# blank rows, or seal a beneficiary token naming nobody — neither of which any
# layer below would notice.
module HoldsDemoIdentity
  extend ActiveSupport::Concern

  included do
    before_action :require_identity
  end

  private

  def identity = @identity ||= ::Demo::UserIdentity.from_session(session[:demo_identity])

  def require_identity
    redirect_to admin_demo_root_path unless identity&.valid?
  end
end
