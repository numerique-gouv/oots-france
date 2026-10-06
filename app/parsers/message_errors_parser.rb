# A `getMessageErrorsResponse`: one `item` per error recorded on a message, an
# attempt that failed leaving one or two.
#
# The children of `item` carry no namespace: the plugin's schema is
# `elementFormDefault="unqualified"`.
class MessageErrorsParser
  include OotsNamespaces

  # Domibus 5.2 records the ebMS error that the correspondent's access point
  # returns in a SOAP fault under this role — `FaultOutHandler#handleFault`
  # writes it, `MSHRole.RECEIVING` —, then records its own `EBMS:0005`, *Error
  # dispatching message*, under `SENDING` for the same attempt. A refusal that
  # comes back in a signal rather than a fault is raised by
  # `ResponseHandler#getResponseStatus` with the correspondent's code, and
  # recorded under `SENDING` by `ReliabilityChecker#handleEbms3Exception`. The
  # only other writer of this role is the receiving side's `FaultInHandler`,
  # which, in the end-to-end loop where one gateway is both correspondents,
  # records the very refusal it sends back.
  SIGNALLED_BY_CORRESPONDENT = 'RECEIVING'.freeze

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, I18n.t('parsers.plugin_unreadable') if @document.errors.any? || response.nil?
  end

  # What made the attempts fail: the last error the correspondent signalled,
  # since the gateway's `EBMS:0005` for that attempt says only that the
  # dispatch failed; the last error the gateway recorded where the
  # correspondent signalled none. Each is the last by the instant its writer
  # recorded, the correspondent's on the correspondent's clock and the
  # gateway's on its own, so no instant orders one role against the other.
  def cause
    signalled = items.select { |item| text_at(item, 'mshRole') == SIGNALLED_BY_CORRESPONDENT }

    last(signalled) || last(items)
  end

  private

  attr_reader :document

  def response = at(document, '//soap:Body/ws:getMessageErrorsResponse')

  def items = all(response, 'item').reject { |item| text_at(item, 'domibusErrorCode').blank? }

  def last(nodes) = nodes.map { |item| delivery_error(item) }.max_by { |error| error.timestamp || Time.zone.at(0) }

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
