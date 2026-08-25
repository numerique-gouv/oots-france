# The first MIME part as it circulated, which chapter 4.8 has the journal keep
# whole and which an auditor comes to this page to read.
#
# Folded, and behind a button naming its size: a metadata document runs to
# several kilobytes, and unfolded it would push every other row of the event off
# the screen.
#
# Rendered verbatim and never re-serialised — the chapter asks for the content
# as it travelled, and a trip through Nokogiri would change the bytes. ERB
# escapes it, and it is escaped rather than trusted: a correspondent chose it.
class RegrepBodyComponent < ViewComponent::Base
  REGION_ID = 'regrep-body'.freeze

  def initialize(body:)
    @body = body
    super()
  end

  # Bytes and not characters, and of what arrived rather than of what is shown:
  # the size announced is the size that circulated.
  def summary = t('components.regrep_body.summary', size: number_to_human_size(@body.bytesize))

  # No chapter fixes an encoding, so a correspondent may legitimately send bytes
  # that are not valid UTF-8, and the journal keeps them whole. A screen cannot
  # show what is not text: the substitution happens here, on the way out, and
  # never on the column — which still answers with exactly what arrived.
  def displayed = @body.scrub
end
