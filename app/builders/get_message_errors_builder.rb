# The request to the `getMessageErrors` operation of the Domibus WS plugin:
# what the gateway recorded of its attempts to deliver one message.
#
# By identifier alone for an exchange: the identifier of a message France
# submits is unique on its own gateway. Only the end-to-end loop, where one
# gateway is both correspondents, gives it twice, and that loop never fails a
# delivery. A connectivity test reads the same way, and names its role,
# `SENDING` — `getMessageErrorsWithAccessPointRole` — only where the gateway
# refuses the form without one: towards France's own access point, whose
# identifier it holds twice (`ConnectivityTesting::ReadVerdict#cause`).
class GetMessageErrorsBuilder < ApplicationBuilder
  attr_reader :message_id, :access_point_role

  def initialize(message_id:, access_point_role: nil)
    @message_id = message_id
    @access_point_role = access_point_role
  end

  # The plugin operation the request element belongs to.
  def operation = access_point_role ? 'getMessageErrorsWithAccessPointRole' : 'getMessageErrors'

  protected

  def template_name = 'get_message_errors.xml.erb'
end
