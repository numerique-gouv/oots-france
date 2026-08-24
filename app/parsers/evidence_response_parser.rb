# An `ExecuteQueryResponse` — a foreign provider answering with evidence.
#
# The requester travels here as a single agent, not a collection: the TDD
# reverse the two between a request and a response.
class EvidenceResponseParser
  include SlotReading

  # The `MainEvidence` classification node of R-EDM-RESP-S062, and the metadata
  # block it is asserted against.
  MAIN_EVIDENCE = './rim:RegistryObjectList/rim:RegistryObject/rim:RegistryObjectList/rim:RegistryObject' \
                  "[rim:Classification/@classificationNode='MainEvidence']".freeze
  EVIDENCE_METADATA = "./rim:Slot[@name='EvidenceMetadata']/rim:SlotValue/sdg:Evidence".freeze

  # `R-EDM-RESP-S006` restricts the status to two values: the evidence travels
  # with the response, or it is announced for later. Only the deferral is named
  # — a response claiming success and carrying nothing stays unreadable, which
  # is what it is.
  UNAVAILABLE = 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Unavailable'.freeze

  AVAILABLE_AT = "./rim:Slot[@name='ResponseAvailableDateTime']/rim:SlotValue/rim:Value".freeze

  def initialize(document)
    @response = at(document, '/query:QueryResponse')
    raise UnreadableMessageError, I18n.t('parsers.not_a_query_response') if @response.nil?
  end

  def request_id = attribute(response, 'requestId')

  def response_id = text_at(response, "./rim:Slot[@name='EvidenceResponseIdentifier']/rim:SlotValue/rim:Value")

  def unavailable? = attribute(response, 'status') == UNAVAILABLE

  # `R-EDM-RESP-S045` requires the slot on a deferral and `R-EDM-RESP-S014`
  # forbids it anywhere else, which is what the guard reads: past it, this
  # answers for a response the rules say carries no such slot.
  #
  # Nil-tolerant beyond that, like everything else read here: an announcement
  # that fails to say until when is still not a failure, and refusing the
  # message over its date would settle the exchange as unreadable — the very
  # tort that reading the status removes.
  #
  # `Date.iso8601` first, and not for its value: `Time.zone.iso8601` rolls a day
  # that does not exist into the next month, so `2026-02-30` comes back as the
  # 2nd of March, and a date invented on a correspondent's behalf is worse than
  # none. It refuses with `Date::Error`, itself an `ArgumentError`.
  def response_available_at
    return unless unavailable?

    announced = text_at(response, AVAILABLE_AT)
    return if announced.blank?

    Date.iso8601(announced)
    Time.zone.iso8601(announced)
  rescue ArgumentError
    nil
  end

  # « Evidence Identifier (for evidence response) » of chapter 4.8, taken from
  # the `Identifier` of the metadata block, and the one thing the journal needs
  # from it.
  #
  # Nil-tolerant, like everything else read here: no error path runs from a
  # portal back to a provider, so refusing an otherwise deliverable response
  # over a journal field would destroy a valid exchange and tell nobody.
  def evidence_identifier
    metadata = at(response, "#{MAIN_EVIDENCE}/#{EVIDENCE_METADATA}")

    text_at(metadata, './sdg:Identifier') if metadata
  end

  # The agent classified `EP`. A collection here, where the error carries a
  # single agent — the TDD shape the two slots differently.
  #
  # The identity comes back as read and never validated, so it can be the empty
  # pair `EbmsIdentity` otherwise promises to refuse: journalling is all that
  # consumes it, and nothing that addresses a message may take it unchecked.
  def provider
    agent = slot_elements('EvidenceProvider', response)
      .filter_map { |element| at(element, './sdg:Agent') }
      .find { |candidate| text_at(candidate, './sdg:Classification') == EvidenceProvider::PROVIDER }

    build_provider(agent) if agent
  end

  # Where a response names the country it came from, and the only place it does.
  def provider_country = provider&.address&.country

  def requester
    agent = slot_content('EvidenceRequester', response, './sdg:Agent')
    identifier = at(agent, './sdg:Identifier')
    name = at(agent, './sdg:Name')

    EvidenceRequester.new(
      id: require_content(identifier&.text, 'parsers.evidence_response.requester_without_id'),
      type_id: require_content(attribute(identifier, 'schemeID'), 'parsers.evidence_response.requester_without_scheme'),
      name: name&.text,
      language: attribute(name, 'lang'),
    )
  end

  private

  attr_reader :response

  def build_provider(agent)
    identifier = at(agent, './sdg:Identifier')

    EvidenceProvider.new(
      identifier: EbmsIdentity.new(id: identifier&.text, type_id: attribute(identifier, 'schemeID')),
      address: Address.new(country: agent_country(agent)),
    )
  end
end
