# The two requests of chapter 4.9, fabricated from the captured one: the first
# asking for the preview, the second carrying back the address France issued.
module PreviewRequests
  FLAG = /(<rim:Slot name="PossibilityForPreview">.*?<rim:Value>)[^<]*/m
  REQUEST_ID = /(<query:QueryRequest[^>]*\sid=")[^"]*/m
  AFTER_FLAG = '<rim:Slot name="ExplicitRequestGiven">'.freeze
  EXCHANGE_ID = "//eb:UserMessage/eb:MessageProperties/eb:Property[@name='ExchangeId']".freeze

  def request_asking_preview(flag = 'true', line: :v2_0)
    requested(line) { |body| flagged(body, flag) }
  end

  # The second request: flagged too, as the second request of step 12 is the
  # first one again, with the address and — on 2.0 — where to send the user
  # back. A fresh `@id`, chapter 4.4 refusing a request identifier used before.
  def second_request(location:, return_location: 'https://portail.example/retour', line: :v2_0,
                     exchange_id: nil, request_id: SecureRandom.uuid, slots: nil)
    added = slots || preview_slots(location, (return_location if line == :v2_0))

    requested(line, exchange_id:) do |body|
      flagged(body, 'true').sub(AFTER_FLAG, "#{added}#{AFTER_FLAG}").sub(REQUEST_ID, "\\1urn:uuid:#{request_id}")
    end
  end

  def preview_slots(location, return_location = nil)
    [location && string_slot('PreviewLocation', location),
     return_location && string_slot('ReturnLocation', return_location)].compact.join
  end

  def string_slot(name, value)
    %(<rim:Slot name="#{name}"><rim:SlotValue xsi:type="rim:StringValueType">) +
      %(<rim:Value>#{value}</rim:Value></rim:SlotValue></rim:Slot>)
  end

  private

  def flagged(body, flag) = body.dup.force_encoding(Encoding::UTF_8).sub(FLAG, "\\1#{flag}")

  def requested(line, exchange_id: nil, &)
    message = line == :v1_2 ? earlier_line_envelope(&) : envelope_with_body('requete', &)
    return message if exchange_id.nil?

    document = Nokogiri::XML(message.raw)
    replace(document, EXCHANGE_ID, exchange_id)
    RetrievedMessageParser.new(document.to_xml)
  end
end
