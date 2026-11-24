# A document of an event as it circulated — the first MIME part, which chapter
# 4.8 has the journal keep whole, or the ebMS header beside it — which an
# auditor comes to this page to read. `part` names which, and so the button and
# the region, two of them sharing the page.
#
# Folded, and behind a button naming its size: either runs to kilobytes, and
# unfolded it would push every other row of the event off the screen.
#
# Shown indented when it reads as well-formed XML in UTF-8 — a correspondent may
# send the whole document on one line — and as it is kept otherwise. Only the
# screen changes: the column still answers with the content as it travelled,
# which chapter 4.8 asks for, and the page says when what it shows is not its
# copy. ERB escapes either form, and it is escaped rather than trusted: a
# correspondent chose it.
class CirculatedDocumentComponent < ViewComponent::Base
  PARTS = %i[regrep_body ebms_header].freeze
  # A byte order mark may precede the declaration, and must not hide it.
  DECLARED_ENCODING = /\A\uFEFF?<\?xml[^>]*\bencoding\s*=\s*["']([^"']+)["']/
  PROLOGUE = /\A\uFEFF?<\?xml\s/

  def self.region_id(part) = part.to_s.dasherize

  def initialize(body:, part:)
    raise ArgumentError, part.inspect unless PARTS.include?(part)

    @body = body
    @part = part
    @indented = (parse&.to_xml(indent: 2, encoding: 'UTF-8', save_with: save_options) if readable_as_utf8?)
    super()
  end

  # Bytes and not characters, and of what arrived rather than of what is shown:
  # the size announced is the size that circulated.
  def summary = t("components.circulated_document.summary.#{@part}", size: number_to_human_size(@body.bytesize))

  def region_id = self.class.region_id(@part)

  def displayed = @indented || @body.scrub

  def indented? = !@indented.nil?

  private

  # No chapter fixes an encoding, so a correspondent may legitimately send bytes
  # that are not valid UTF-8, or declare another encoding, and the journal keeps
  # them whole. Read as UTF-8, such a body would show a text it does not hold.
  def readable_as_utf8?
    return false unless @body.valid_encoding?

    declared = @body[DECLARED_ENCODING, 1]
    declared.nil? || declared.casecmp?('UTF-8')
  end

  # Any error, not only a fatal one, keeps the body as it is: libxml carries on
  # past an undeclared prefix, and what it then built would no longer show the
  # same names in the same namespaces. `nonet`, and neither `noent` nor
  # `dtdload`: no external entity is fetched from a document a correspondent wrote.
  def parse
    document = Nokogiri::XML(@body, nil, 'UTF-8') { |config| config.strict.nonet.noblanks }
    document if document.errors.empty?
  rescue Nokogiri::XML::SyntaxError
    nil
  end

  # The screen adds no declaration where the message made none.
  def save_options
    options = Nokogiri::XML::Node::SaveOptions::DEFAULT_XML
    PROLOGUE.match?(@body) ? options : options | Nokogiri::XML::Node::SaveOptions::NO_DECLARATION
  end
end
