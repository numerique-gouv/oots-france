# A `retrieveMessageResponse` envelope: the ebMS header, the RegRep body it
# carries base64-encoded, and the evidence alongside when there is one.
class RetrievedMessageParser
  include OotsNamespaces

  REGREP = 'application/x-ebrs+xml'.freeze
  PDF = 'application/pdf'.freeze

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, I18n.t('parsers.retrieved_message.unreadable_envelope') if @document.errors.any?

    @header = EbmsHeaderParser.new(@document)
  end

  delegate :action, :conversation_id, :exchange_id, :sender, :sent_at, :specification_id, to: :header

  # The ebMS action decides, and it alone: a response status says nothing about
  # the body's shape, and the exception type carries a prefix that identifies no
  # namespace, per OotsNamespaces.
  def body
    @body ||= case action
              when EbmsAction::EXECUTE_QUERY_REQUEST then EvidenceRequestParser.new(body_document)
              when EbmsAction::EXECUTE_QUERY_RESPONSE then EvidenceResponseParser.new(body_document)
              when EbmsAction::EXCEPTION_RESPONSE then ErrorResponseParser.new(body_document)
              else raise UnreadableMessageError, I18n.t('parsers.retrieved_message.unknown_action', action:)
              end
  end

  # The evidence as it arrived, and the part that carried it: chapter 4.8 asks
  # the response flow for « MIME type and MIME content identifier » of evidence
  # content referenced by a `rim:RepositoryItemRef`, and the reference it names
  # is the `href` of the `eb:PartInfo` — the same `cid:` on both sides.
  #
  # Looked up by type, as the payload itself is: the identifier is recorded from
  # the header rather than read back from the body, which nothing here parses
  # for it.
  def evidence
    declared = payload_part(PDF)

    MimePart.new(mime_type: declared[:mime_type], content_id: declared[:href],
      content: payload_at(declared[:href]))
  end

  # The first MIME part as it arrived, bytes and declared type: chapter 4.8 asks
  # both its tables for it, and `retention_downloaded="0"` has Domibus erase the
  # message the instant `retrieveMessage` returns — nothing can read it twice.
  #
  # Read past Nokogiri deliberately, and by position rather than by type: a body
  # too malformed to parse is the one an auditor most needs the bytes of, and
  # `body_document` would raise before it.
  def first_part
    declared = header.payload_parts.first
    raise UnreadableMessageError, I18n.t('parsers.retrieved_message.no_part') if declared.nil?
    # Guarded like the identifier `payload` looks up, and for a sharper reason:
    # a missing attribute reads as nil on both sides, so an unguarded lookup
    # would match the first payload declaring no identifier and hand back its
    # bytes as the announced part.
    raise UnreadableMessageError, I18n.t('parsers.retrieved_message.part_without_href') if declared[:href].nil?

    MimePart.new(mime_type: declared[:mime_type], content_id: declared[:href],
      content: as_text(payload_at(declared[:href])))
  end

  private

  attr_reader :document, :header

  def body_document
    @body_document ||= begin
      parsed = Nokogiri::XML(payload(REGREP))
      raise UnreadableMessageError, I18n.t('parsers.retrieved_message.unreadable_body') if parsed.errors.any?

      parsed
    end
  end

  def payload(mime_type) = payload_at(payload_part(mime_type)[:href])

  def payload_part(mime_type)
    declared = header.payload_parts.find { |part| part[:mime_type] == mime_type && part[:href] }
    raise UnreadableMessageError, I18n.t('parsers.retrieved_message.no_payload', type: mime_type) if declared.nil?

    declared
  end

  # Base64 decodes to bytes; the journal keeps this part as text, so they are
  # tagged and never transcoded. Bytes that are not valid UTF-8 are kept as they
  # came: no chapter fixes an encoding — 4.7.2 profiles `MimeType` and
  # `CompressionType`, and not the `CharacterSet` property the AS4 profile
  # recommends — and chapter 4.8 asks for the content whole. What is archived is
  # therefore what arrived, well formed or not: this is a log, not a validator.
  def as_text(bytes) = bytes.force_encoding(Encoding::UTF_8)

  def payload_at(identifier)
    encoded = all(document, '//soap:Body/ws:retrieveMessageResponse/payload')
      .find { |payload| attribute(payload, 'payloadId') == identifier }
      &.then { |payload| text_at(payload, './value') }

    raise UnreadableMessageError, I18n.t('parsers.retrieved_message.payload_missing', id: identifier) if encoded.nil?

    Base64.decode64(encoded)
  end
end
