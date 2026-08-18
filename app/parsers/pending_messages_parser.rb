# A `listPendingMessagesResponse`: the identifiers of the messages the gateway
# is holding for us.
class PendingMessagesParser
  include OotsNamespaces

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, I18n.t('parsers.plugin_unreadable') if @document.errors.any?
  end

  def message_ids = all(document, '//soap:Body/ws:listPendingMessagesResponse/messageID').map(&:text)

  private

  attr_reader :document
end
