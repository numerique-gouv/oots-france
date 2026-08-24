# The state of an exchange, as a DSFR badge.
#
# The colour is a reading of the state, not a property of it: the model says an
# exchange failed, this says that reads as an error.
class ExchangeStatusComponent < ViewComponent::Base
  BADGES = {
    'pending' => :new,
    'sent' => :info,
    'preview_required' => :warning,
    'deferred' => :warning,
    'delivered' => :success,
    'failed' => :error,
  }.freeze

  def initialize(status:)
    @status = status
    super()
  end

  # The DSFR component is rendered directly: the `dsfr_badge` helper is put on
  # ActionView, and a ViewComponent does not inherit from it.
  def call
    render(DsfrComponent::BadgeComponent.new(status: BADGES.fetch(@status, :info), size: :sm)) do
      t("admin.journal.exchanges.statuses.#{@status}", default: @status)
    end
  end
end
