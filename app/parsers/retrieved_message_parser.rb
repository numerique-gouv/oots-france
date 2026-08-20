# A `retrieveMessageResponse` envelope: the ebMS header, the RegRep body it
# carries base64-encoded, and the evidence alongside when there is one.
class RetrievedMessageParser
  include OotsNamespaces

  REGREP = 'application/x-ebrs+xml'.freeze
  PDF = 'application/pdf'.freeze

  def initialize(xml)
    @document = Nokogiri::XML(xml)
    raise UnreadableMessageError, 'Enveloppe SOAP illisible.' if @document.errors.any?

    @header = EbmsHeaderParser.new(@document)
  end

  delegate :action, :conversation_id, :exchange_id, :sender, :specification_id, to: :header

  # The ebMS action decides, and it alone: a response status says nothing about
  # the body's shape, and the exception type carries a prefix that identifies no
  # namespace, per OotsNamespaces.
  def body
    @body ||= case action
              when EbmsAction::EXECUTE_QUERY_REQUEST then EvidenceRequestParser.new(body_document)
              when EbmsAction::EXECUTE_QUERY_RESPONSE then EvidenceResponseParser.new(body_document)
              when EbmsAction::EXCEPTION_RESPONSE then ErrorResponseParser.new(body_document)
              else raise UnreadableMessageError, "Action ebMS inconnue : « #{action} »."
              end
  end

  def evidence = payload(PDF)

  private

  attr_reader :document, :header

  def body_document
    @body_document ||= begin
      parsed = Nokogiri::XML(payload(REGREP))
      raise UnreadableMessageError, 'Corps RegRep illisible.' if parsed.errors.any?

      parsed
    end
  end

  def payload(mime_type)
    identifier = header.payload_identifiers[mime_type]
    raise UnreadableMessageError, "Pas de charge « #{mime_type} » dans le message reçu." if identifier.nil?

    encoded = all(document, '//soap:Body/ws:retrieveMessageResponse/payload')
      .find { |payload| attribute(payload, 'payloadId') == identifier }
      &.then { |payload| text_at(payload, './value') }

    raise UnreadableMessageError, "Charge « #{identifier} » annoncée mais absente." if encoded.nil?

    Base64.decode64(encoded)
  end
end
