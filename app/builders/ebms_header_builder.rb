# The ebMS header that accompanies every message. On the wire it is the SOAP
# header of the envelope submitted to Domibus; the RegRep body does not contain
# it, which is why `scripts/valideSchematron.sh` validates the two separately —
# the header against `EDM-ebMS.sch`, the body against its own rules.
class EbmsHeaderBuilder < ApplicationBuilder
  SERVICE = 'QueryManager'.freeze
  SERVICE_TYPE = 'urn:oasis:names:tc:ebcore:ebrs:ebms:binding:1.0'.freeze
  REGREP_MIME_TYPE = 'application/x-ebrs+xml'.freeze

  attr_reader :action, :recipient, :sender, :original_sender, :final_recipient,
    :payload_id, :conversation_id, :attachment, :timestamp, :message_id, :exchange_id

  # `original_sender` and `final_recipient` are C1 and C4 of the four-corner
  # model. Passed in rather than derived: they swap between a request and a
  # response, and only the message knows which way it travels.
  def initialize(
    action:, recipient:, original_sender:, final_recipient:, payload_id:,
    conversation_id: nil, exchange_id: nil, attachment: EmptyAttachment.new,
    sender: AccessPoint.sender, clock: Clock.new, uuid: UuidGenerator.new
  )
    @action = action
    @recipient = recipient
    @sender = sender
    @original_sender = original_sender.validate!("L'émetteur d'origine (C1)")
    @final_recipient = final_recipient.validate!('Le destinataire final (C4)')
    @payload_id = payload_id
    @conversation_id = conversation_id
    @attachment = attachment
    @timestamp = clock.now
    @message_id = "#{uuid.next}@#{Settings.identifier_suffix}"
    # A provider reuses the exchange identifier it received, so that both legs
    # of the exchange can be tied together; a requester mints a new one.
    @exchange_id = exchange_id || uuid.next
  end

  protected

  def template_name = 'ebms_header.xml.erb'
end
