module ApplicationHelper
  # Both correlation identifiers are UUIDs — 36 characters — and a listing that
  # carries the two of them side by side has nothing left for the columns an
  # operator reads first. The tail is what one actually compares between two
  # rows; the whole identifier stays one hover away, and is written out in full
  # on the page the link leads to.
  ABBREVIATED_IDENTIFIER_LENGTH = 6

  def abbreviated_identifier(identifier) = "…#{identifier.to_s.last(ABBREVIATED_IDENTIFIER_LENGTH)}"

  # An address the console holds and an operator will want to open — the
  # Semantic Repository's name for an evidence type, the preview space a
  # correspondent points at — rather than thirty characters to copy by hand.
  #
  # The scheme is vetted and not assumed: both come from a received message, so
  # they are whatever the correspondent wrote, and `link_to` escapes the HTML
  # without looking at the scheme — `javascript:…` in an `href` runs on our own
  # origin. What a browser cannot open reads as the plain text it already was.
  def external_link(address)
    return address unless opens_in_a_browser?(address)

    link_to address, address, class: 'fr-link', target: '_blank', rel: 'noopener'
  end

  private

  def opens_in_a_browser?(address)
    uri = URI.parse(address.to_s)

    uri.scheme.in?(ErrorResponseParser::ACCEPTED_SCHEMES) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end
end
