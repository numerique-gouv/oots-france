# A `getMessageErrorsResponse`: one `item` per error the gateway recorded on a
# message, each attempt that failed leaving its own.
#
# The children of `item` carry no namespace: the plugin's schema is
# `elementFormDefault="unqualified"`.
class MessageErrorsParser
  include OotsNamespaces

  # An error the gateway recorded as the one receiving the message: in the
  # end-to-end loop, where one gateway is both correspondents, the same
  # identifier names both sides. Only the attempts to send are about delivery.
  RECEIVING = 'RECEIVING'.freeze

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, I18n.t('parsers.plugin_unreadable') if @document.errors.any? || response.nil?
  end

  def errors
    all(response, 'item')
      .reject { |item| text_at(item, 'mshRole') == RECEIVING || text_at(item, 'domibusErrorCode').blank? }
      .map { |item| delivery_error(item) }
  end

  # The last attempt, by the instant the gateway recorded: nothing in the
  # schema promises the items in order.
  def latest = errors.max_by { |error| error.timestamp || Time.zone.at(0) }

  private

  attr_reader :document

  def response = at(document, '//soap:Body/ws:getMessageErrorsResponse')

  def delivery_error(item)
    DeliveryError.new(
      code: text_at(item, 'domibusErrorCode'),
      detail: text_at(item, 'errorDetail'),
      timestamp: instant(text_at(item, 'timestamp')),
    )
  end

  def instant(value)
    Time.iso8601(value) if value.present?
  rescue ArgumentError
    nil
  end
end
