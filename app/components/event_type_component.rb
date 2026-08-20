class EventTypeComponent < ViewComponent::Base
  BADGES = {
    'request_sent' => :info,
    'request_received' => :info,
    'response_sent' => :success,
    'response_received' => :success,
    'evidence_delivered' => :success,
    'error_sent' => :warning,
    'error_received' => :warning,
    'request_refused' => :error,
    'response_refused' => :error,
  }.freeze

  def initialize(event_type:)
    @event_type = event_type
    super()
  end

  def call
    render(DsfrComponent::BadgeComponent.new(status: BADGES.fetch(@event_type, :info), size: :sm)) do
      t("admin.journal.event_types.#{@event_type}", default: @event_type)
    end
  end
end
