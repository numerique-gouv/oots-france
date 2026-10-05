# A notification Domibus pushes to us, rather than waiting to be polled.
#
# It is a SOAP call, not a REST hook: the plugin expects a backend implementing
# `BackendInterface`, whose operations are named in the body — `receiveSuccess`,
# `receiveFailure`, `sendSuccess`, `sendFailure`, `messageStatusChange`.
#
# Only the operation, the message identifier and its status are read. What the
# message actually contains is fetched afterwards, with `retrieveMessage`: the
# notification says a message is there, it does not carry it. Nor does a change
# of status carry its cause, which `getMessageErrors` reads.
class PushNotificationParser
  include OotsNamespaces

  # The one that says a message arrived for us.
  RECEIVE_SUCCESS = 'receiveSuccess'.freeze

  # Sent at every change of status of every message, either way round, and
  # without the condition on the PMode that `sendFailure` depends on. Two of its
  # statuses say that a message we submitted has not reached its recipient:
  # the gateway will try again, or it has given up. The others are acknowledged
  # without doing anything.
  MESSAGE_STATUS_CHANGE = 'messageStatusChange'.freeze
  WAITING_FOR_RETRY = 'WAITING_FOR_RETRY'.freeze
  SEND_FAILURE = 'SEND_FAILURE'.freeze

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, 'Notification illisible.' if @document.errors.any? || operation.nil?
  end

  # Read as a local name, ignoring whatever prefix the caller chose to bind.
  def operation = at(document, '//soap:Body/*')&.name

  def message_id = text_at(document, '//soap:Body//*[local-name()="messageID"]')

  def message_status = text_at(document, '//soap:Body//*[local-name()="messageStatus"]')

  def message_arrived? = operation == RECEIVE_SUCCESS

  def delivery_failed?
    operation == MESSAGE_STATUS_CHANGE && [WAITING_FOR_RETRY, SEND_FAILURE].include?(message_status)
  end

  private

  attr_reader :document
end
