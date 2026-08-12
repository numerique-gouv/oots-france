# A notification Domibus pushes to us, rather than waiting to be polled.
#
# It is a SOAP call, not a REST hook: the plugin expects a backend implementing
# `BackendInterface`, whose operations are named in the body — `receiveSuccess`,
# `receiveFailure`, `sendSuccess`, `sendFailure`, `messageStatusChange`.
#
# Only the operation and the message identifier are read. What the message
# actually contains is fetched afterwards, with `retrieveMessage`: the
# notification says a message is there, it does not carry it.
class PushNotificationParser
  include OotsNamespaces

  # The one that says a message arrived for us. The others report on messages we
  # sent, and are acknowledged without doing anything yet.
  RECEIVE_SUCCESS = 'receiveSuccess'.freeze

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, 'Notification illisible.' if @document.errors.any? || operation.nil?
  end

  # Read as a local name, ignoring whatever prefix the caller chose to bind.
  def operation = at(document, '//soap:Body/*')&.name

  def message_id = text_at(document, '//soap:Body//*[local-name()="messageID"]')

  def message_arrived? = operation == RECEIVE_SUCCESS

  private

  attr_reader :document
end
