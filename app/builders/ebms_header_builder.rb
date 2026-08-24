# The ebMS header that accompanies every message. On the wire it is the SOAP
# header of the envelope submitted to Domibus; the RegRep body does not contain
# it, which is why `scripts/validate_schematron.sh` validates the two separately —
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
    conversation_id:, exchange_id:, attachment: EmptyAttachment.new,
    sender: AccessPoint.sender, clock: Clock.new, uuid: UuidGenerator.new
  )
    @action = action
    # Validated like C1 and C4, and for the same reason: an access point with
    # no identity travels to the gateway as a property it accepts and routes
    # nowhere, which shows up only as silence on the other side.
    @recipient = recipient.validate!(:recipient_access_point)
    @sender = sender
    @original_sender = original_sender.validate!(:original_sender)
    @final_recipient = final_recipient.validate!(:final_recipient)
    @payload_id = payload_id
    @conversation_id = conversation_id
    @attachment = attachment
    @timestamp = clock.now
    @message_id = "#{uuid.next}@#{Settings.identifier_suffix}"
    # Both required, and neither minted here. Chapter 4.4 has every message of
    # one exchange reuse its `ExchangeId` — a value drawn at serialisation time
    # would be a new one per message, which is the correlation the preview
    # depends on, lost.
    @exchange_id = exchange_id
  end

  protected

  def template_name = 'ebms_header.xml.erb'
end
