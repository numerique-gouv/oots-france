# A `getStatusResponse`: the bare status the gateway holds for one message —
# `NOT_FOUND` for one it does not know, or no longer keeps.
class MessageStatusParser
  include OotsNamespaces

  ACKNOWLEDGED = %w[ACKNOWLEDGED ACKNOWLEDGED_WITH_WARNING].freeze
  SEND_FAILURE = 'SEND_FAILURE'.freeze
  NOT_FOUND = 'NOT_FOUND'.freeze

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, I18n.t('parsers.plugin_unreadable') if @document.errors.any? || status.blank?
  end

  def status = text_at(document, '//soap:Body/ws:getStatusResponse')&.strip

  def acknowledged? = ACKNOWLEDGED.include?(status)

  def failed? = status == SEND_FAILURE

  def not_found? = status == NOT_FOUND

  private

  attr_reader :document
end
