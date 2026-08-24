module ApplicationHelper
  # Both correlation identifiers are UUIDs — 36 characters — and a listing that
  # carries the two of them side by side has nothing left for the columns an
  # operator reads first. The tail is what one actually compares between two
  # rows; the whole identifier stays one hover away, and is written out in full
  # on the page the link leads to.
  ABBREVIATED_IDENTIFIER_LENGTH = 6

  def abbreviated_identifier(identifier) = "…#{identifier.to_s.last(ABBREVIATED_IDENTIFIER_LENGTH)}"
end
