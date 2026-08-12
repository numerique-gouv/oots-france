# The endpoint Domibus calls when a message arrives for us. It acknowledges at
# once and queues the work: the gateway gives up after a while, so holding its
# connection open turns a slow correspondent into a lost notification.
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

    ProcessIncomingMessageJob.perform_later(notification.message_id) if notification.message_arrived?

    head :ok
  rescue UnreadableMessageError => e
    # 400 and not 500: the gateway retries a 500 with the same body, and a body
    # we cannot read will not become readable.
    Rails.logger.error("Notification Domibus illisible : #{e.message}")
    head :bad_request
  end

  private

  def authenticate
    authenticate_or_request_with_http_basic('OOTS-France') do |login, password|
      expected = Settings.gateway_notification_credentials

      ActiveSupport::SecurityUtils.secure_compare(login, expected[:login]) &
        ActiveSupport::SecurityUtils.secure_compare(password, expected[:password])
    end
  end
end
