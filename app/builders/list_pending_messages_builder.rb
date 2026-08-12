# The request to the `listPendingMessages` operation of the Domibus WS plugin.
#
# The conversation filter is optional, and the sweep leaves it out: it collects
# whatever the gateway still holds, whichever exchange it belongs to. Nothing
# passes it today — it is kept because a frozen reference envelope documents the
# filtered form, and those fixtures are what this rewrite is measured against.
class ListPendingMessagesBuilder < ApplicationBuilder
  attr_reader :conversation_id

  def initialize(conversation_id: nil)
    @conversation_id = conversation_id
  end

  protected

  def template_name = 'list_pending_messages.xml.erb'
end
