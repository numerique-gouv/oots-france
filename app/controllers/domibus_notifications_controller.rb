# The endpoint Domibus calls when a message arrives for us, or when one we
# submitted fails to reach its recipient. It acknowledges at once and queues the
# work: the gateway gives up after a while, so holding its connection open
# turns a slow correspondent into a lost notification.
#
# Authenticated, because anyone reaching this route can trigger processing.
# Domibus puts basic credentials on the calls it makes (`wsplugin.push.auth.*`).
#
# `ActionController::API` and not `ApplicationController`: no session, no
# cookie, and therefore no CSRF protection to disable.
class DomibusNotificationsController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods

  before_action :authenticate

  def create
    notification = PushNotificationParser.new(request.raw_post)

    if notification.message_arrived?
      ProcessIncomingMessageJob.perform_later(notification.message_id)
    elsif notification.delivery_failed?
      RecordDeliveryFailureJob.perform_later(notification.message_id, notification.message_status)
    end

    answer(PushNotificationAcknowledgementBuilder, :ok)
  rescue UnreadableMessageError => e
    # The plugin retries a refused notification whatever the answer, then raises
    # its alert (`WSPluginMessageSender`, Domibus `5.2-JEE10`): the fault only
    # tells it the call failed, in the form its contract declares.
    Rails.logger.error("Notification Domibus illisible : #{e.message}")
    answer(PushNotificationFaultBuilder, :bad_request)
  end

  private

  # SOAP, and never `head`: the plugin dispatches through CXF, which refuses an
  # answer typed `text/html` without parsing it — and `head` types its empty
  # body `text/html` for a caller sending `Accept: */*`, as the plugin does.
  def answer(builder, status)
    render body: builder.new.render, content_type: 'application/soap+xml', status:
  end

  def authenticate
    authenticate_or_request_with_http_basic('OOTS-France') do |login, password|
      expected = Settings.gateway_notification_credentials

      ActiveSupport::SecurityUtils.secure_compare(login, expected[:login]) &
        ActiveSupport::SecurityUtils.secure_compare(password, expected[:password])
    end
  end
end
