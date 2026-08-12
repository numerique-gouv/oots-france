# An `ExecuteQueryResponse` — a foreign provider answering with evidence.
#
# The requester travels here as a single agent, not a collection: the TDD
# reverse the two between a request and a response.
class EvidenceResponseParser
  include SlotReading

  def initialize(document)
    @response = at(document, '/query:QueryResponse')
    raise UnreadableMessageError, "Le message reçu n'est pas une QueryResponse." if @response.nil?
  end

  def request_id = attribute(response, 'requestId')

  def requester
    agent = slot_content('EvidenceRequester', response, './sdg:Agent')
    identifier = at(agent, './sdg:Identifier')
    name = at(agent, './sdg:Name')

    EvidenceRequester.new(
      id: require_content(identifier&.text, "L'agent requêteur est sans identifiant"),
      type_id: require_content(attribute(identifier, 'schemeID'), "L'agent requêteur est sans schéma d'identifiant"),
      name: name&.text,
      language: attribute(name, 'lang'),
    )
  end

  private

  attr_reader :response
end
