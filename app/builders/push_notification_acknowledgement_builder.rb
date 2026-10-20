# The answer to a notification the Domibus WS plugin pushes: every operation of
# its `BackendInterface` is request/response, and each response message carries
# no part, so the answer is a SOAP 1.2 envelope with an empty `Body`
# (`BackendService.wsdl`, Domibus `5.2-JEE10`).
class PushNotificationAcknowledgementBuilder < ApplicationBuilder
  protected

  def template_name = 'push_notification_acknowledgement.xml.erb'
end
