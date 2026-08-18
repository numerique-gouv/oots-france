# An `ExecuteQueryResponse` — a foreign provider answering with evidence.
#
# The requester travels here as a single agent, not a collection: the TDD
# reverse the two between a request and a response.
class EvidenceResponseParser
  include SlotReading

  def initialize(document)
    @response = at(document, '/query:QueryResponse')
    raise UnreadableMessageError, I18n.t('parsers.not_a_query_response') if @response.nil?
  end

  def request_id = attribute(response, 'requestId')

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
end
