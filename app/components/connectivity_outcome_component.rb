# The outcome of the last connectivity test towards a party, as a DSFR badge.
class ConnectivityOutcomeComponent < ViewComponent::Base
  BADGES = {
    AccessPointRow::NEVER_TESTED => :info,
    ConnectivityTest::PENDING => :new,
    ConnectivityTest::ACKNOWLEDGED => :success,
    ConnectivityTest::REFUSED_FOR_CONFIGURATION => :error,
    ConnectivityTest::FAILED => :error,
    ConnectivityTest::NO_VERDICT => :warning,
    ConnectivityTest::NOT_SUBMITTED => :error,
  }.freeze

  def initialize(outcome:)
    @outcome = outcome
    super()
  end

  def call
    render(DsfrComponent::BadgeComponent.new(status: BADGES.fetch(@outcome), size: :sm)) do
      t("components.connectivity_outcome.#{@outcome}")
    end
  end
end
