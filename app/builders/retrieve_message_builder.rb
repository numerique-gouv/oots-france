# The request to the `retrieveMessage` operation of the Domibus WS plugin.
#
# The PMode carries `retention_downloaded="0"`, so the gateway erases a message
# as soon as it is considered downloaded: this request can be answered once, and
# what it returns has to be dealt with there and then.
class RetrieveMessageBuilder < ApplicationBuilder
  attr_reader :message_id

  def initialize(message_id:)
    @message_id = message_id
  end

  protected

  def template_name = 'retrieve_message.xml.erb'
end
