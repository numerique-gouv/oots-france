# Escaping for the message templates, to be applied to every interpolated
# value that is not a literal of the code: `ApplicationBuilder` renders with
# plain ERB, and ActionView escapes for HTML rather than XML anyway.
#
# A foreign requester's identifier and name are read from the message it sent
# and re-emitted in our answer, entities already decoded by the parser —
# re-emitted raw, they yield malformed XML at best and elements the sender
# dictates at worst.
module XmlEscaping
  ENTITIES = {
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
  }.freeze

  # No apostrophe: it would only need escaping inside an attribute delimited
  # by apostrophes, which the templates never use, and escaping it would
  # clutter every French name for nothing.
  def escape(value)
    return '' if value.nil?

    value.to_s.gsub(/[&<>"]/, ENTITIES)
  end
end
