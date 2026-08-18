# A `submitResponse`: what the gateway called the message we just handed it.
#
# The gateway also returns a `messageEntityID`. Nothing needs it yet; it is
# read so that a gateway log can be tied to an exchange without guessing.
class SubmittedMessageParser
  include OotsNamespaces

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, I18n.t('parsers.plugin_unreadable') if @document.errors.any?
  end

  def message_id = text_at(document, '//soap:Body/ws:submitResponse/messageID')

  def entity_id = text_at(document, '//soap:Body/ws:submitResponse/messageEntityID')

  private

  attr_reader :document
end
