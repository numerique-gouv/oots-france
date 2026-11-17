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
    'declined' => :info,
    'unmatched' => :warning,
    'failed' => :error,
  }.freeze

  def initialize(exchange:)
    @exchange = exchange
    super()
  end

  # The DSFR component is rendered directly: the `dsfr_badge` helper is put on
  # ActionView, and a ViewComponent does not inherit from it.
  def call
    render(DsfrComponent::BadgeComponent.new(status: BADGES.fetch(status, :info), size: :sm)) { wording }
  end

  private

  def status = @exchange.status

  # Chapter 4.9 §1 answers the same empty list whether the user refused or
  # nothing matched them, and `R-EDM-RESP-S016` leaves no slot to say which:
  # France, requesting, cannot tell the two apart.
  def wording
    return t('admin.journal.exchanges.outgoing_statuses.declined') if status == 'declined' && !@exchange.incoming?

    t("admin.journal.exchanges.statuses.#{status}", default: status)
  end
end
