# The refusal of a notification the application cannot read: a SOAP 1.2 fault
# whose code is `env:Sender`, the one SOAP 1.2 Part 2 § 7.5.2.2 binds to the
# HTTP status 400.
#
# No `Detail`: `BackendService.wsdl` declares a `BackendFaultDetail`, but nothing
# defines the values of its `code` and `message`, and the plugin does not read
# the fault — it treats any failed dispatch alike.
class PushNotificationFaultBuilder < ApplicationBuilder
  protected

  def template_name = 'push_notification_fault.xml.erb'
end
