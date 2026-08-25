# The ebMS header of a message the gateway handed us.
class EbmsHeaderParser
  include OotsNamespaces

  def initialize(document)
    @user_message = at(document, '//eb:Messaging/eb:UserMessage')
    raise UnreadableMessageError, I18n.t('parsers.ebms_header.no_header') if @user_message.nil?
  end

  def action = text_at(user_message, './eb:CollaborationInfo/eb:Action')

  def conversation_id = text_at(user_message, './eb:CollaborationInfo/eb:ConversationId')

  def exchange_id = property('ExchangeId')

  # R-EDM-ebMS-019 requires the property, R-EDM-ebMS-038 fixes its value. It is
  # the same version the body declares in its `SpecificationIdentifier` slot,
  # and the two must agree — see `EdmSpecification`.
  def specification_id = property('SpecificationId')

  # The instant the sending gateway stamped, and the only origin a timeout of
  # chapter 4.4 can be counted from: our own reception says when we took the
  # message in hand, not when it arrived — `retention_undownloaded` lets the
  # gateway hold one for two and a half days, which the periodic sweep then
  # brings back as if it were new.
  def sent_at
    stamped = text_at(user_message, './eb:MessageInfo/eb:Timestamp')
    Time.zone.iso8601(stamped.to_s)
  rescue ArgumentError
    raise UnreadableMessageError, I18n.t('parsers.ebms_header.timestamp_unreadable', value: stamped)
  end

  # Where the message came from, and therefore where our answer goes. Read as an
  # access point rather than a bare string: a response without a recipient goes
  # nowhere, and the failure must show here.
  def sender
    party = at(user_message, './eb:PartyInfo/eb:From/eb:PartyId')
    raise UnreadableMessageError, I18n.t('parsers.ebms_header.no_sender') if party.nil?

    AccessPoint.new(id: party.text, type_id: attribute(party, 'type'))
      .validate!(:message_sender, error: UnreadableMessageError)
  end

  # The parts in the order the header declares them, which is what chapter 4.8
  # asks the log for: « full content of first MIME part », the first one and not
  # the one whose type happens to suit.
  #
  # A request and an exception leave no room for doubt — `R-EDM-ebMS-023` allows
  # them one part and `R-EDM-ebMS-030` fixes its type, both fatal. A response is
  # weaker: `R-EDM-ebMS-032` asks for the RegRep document first, but only at
  # warning severity, so a correspondent can put something else there and still
  # break no fatal rule. Reading by position and recording what was declared is
  # what makes that gap visible; reading by type would hide it.
  def payload_parts
    all(user_message, './eb:PayloadInfo/eb:PartInfo').map do |part|
      { mime_type: part_property(part, 'MimeType'), href: attribute(part, 'href') }
    end
  end

  # { 'application/x-ebrs+xml' => 'cid:…', 'application/pdf' => 'cid:…' }
  def payload_identifiers = payload_parts.to_h { |part| part.values_at(:mime_type, :href) }

  private

  attr_reader :user_message

  def property(name) = text_at(user_message, "./eb:MessageProperties/eb:Property[@name='#{name}']")

  def part_property(part, name) = text_at(part, "./eb:PartProperties/eb:Property[@name='#{name}']")
end
