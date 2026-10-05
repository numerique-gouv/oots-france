# The request to the `getMessageErrors` operation of the Domibus WS plugin:
# what the gateway recorded of its attempts to deliver one message.
#
# By identifier alone, and not `getMessageErrorsWithAccessPointRole`: the
# identifier of a message France submits is unique on its own gateway. Only the
# end-to-end loop, where one gateway is both correspondents, gives it twice, and
# that loop never fails a delivery.
class GetMessageErrorsBuilder < ApplicationBuilder
  attr_reader :message_id

  def initialize(message_id:)
    @message_id = message_id
  end

  protected

  def template_name = 'get_message_errors.xml.erb'
end
