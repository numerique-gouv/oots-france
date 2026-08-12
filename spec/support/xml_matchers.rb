# Compares a rendered message to a reference document of
# `spec/fixtures/reference/`, as a document and not as bytes: element order,
# names, namespaces, attributes and text, ignoring whitespace *between*
# elements. Text inside an element is compared as is, so a value that gains a
# space still fails.
#
# UUIDs are canonicalised — each distinct one replaced by a placeholder
# numbered in order of first appearance, on both sides — which keeps what
# matters: the `cid:` of the ebMS header must still designate the very payload
# the body carries, while the drawn values and their order stop counting.
#
# Conformance itself is judged by `scripts/validate_schematron.sh`, against the
# rules published with the TDD.
module XmlNormalisation
  require 'digest'

  UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i

  def normalise_xml(xml)
    document = Nokogiri::XML(xml, &:noblanks)

    decode_payloads(document)

    document.xpath('//text()').each do |node|
      node.remove if node.text.strip.empty?
    end

    canonicalise_uuids(document.canonicalize)
  end

  # A submission carries its RegRep message base64-encoded: left encoded, any
  # difference of indentation *inside* it would read as a different message.
  # XML payloads are decoded and normalised like the envelope around them,
  # binary ones replaced by a digest of their bytes.
  def decode_payloads(document)
    document.xpath('//payload/value').each do |value|
      decoded = decode(value.text)
      next if decoded.nil?

      if decoded.lstrip.start_with?('<')
        value.content = ''
        value.add_child(Nokogiri::XML(decoded, &:noblanks).root)
      else
        value.content = "sha256:#{Digest::SHA256.hexdigest(decoded)}"
      end
    end
  end

  # Decoded the way a MIME decoder does, ignoring anything outside the base64
  # alphabet: the references wrap a payload in literal parentheses (see
  # `spec/fixtures/README.md`), so comparing the *encoding* would report a
  # difference where the bytes are identical.
  def decode(content)
    Base64.decode64(content.gsub(%r{[^A-Za-z0-9+/=]}, ''))
  rescue ArgumentError, Encoding::CompatibilityError
    nil
  end

  private

  def canonicalise_uuids(xml)
    seen = {}

    xml.gsub(UUID) do |uuid|
      seen[uuid.downcase] ||= format('uuid-%03d', seen.size + 1)
    end
  end
end

RSpec::Matchers.define :be_equivalent_xml_to do |expected|
  include XmlNormalisation

  match do |actual|
    @normalised_actual = normalise_xml(actual)
    @normalised_expected = normalise_xml(expected)

    @normalised_actual == @normalised_expected
  end

  failure_message do |_actual|
    differences = @normalised_expected.each_line.zip(@normalised_actual.each_line)
      .reject { |expected_line, actual_line| expected_line == actual_line }
      .first(5)
      .map { |expected_line, actual_line| "  attendu : #{expected_line.inspect}\n  obtenu  : #{actual_line.inspect}" }

    "Le XML rendu diffère de la référence.\n#{differences.join("\n\n")}"
  end
end
