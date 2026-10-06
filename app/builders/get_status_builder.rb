# The request to the `getStatusWithAccessPointRole` operation of the Domibus WS
# plugin: where the gateway stands with one message France sent.
#
# The role is mandatory here: a test message towards France's own access point
# exists twice on its gateway, once sent and once received, and the form
# without a role then raises
# `DuplicateMessageException` (`MessageRetrieverImpl.getStatus`, Domibus
# `5.2-JEE10`).
class GetStatusBuilder < ApplicationBuilder
  attr_reader :message_id, :access_point_role

  def initialize(message_id:, access_point_role:)
    @message_id = message_id
    @access_point_role = access_point_role
  end

  protected

  def template_name = 'get_status.xml.erb'
end
