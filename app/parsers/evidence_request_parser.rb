# An `ExecuteQueryRequest` a foreign correspondent addressed to France.
#
# Everything it cannot read raises UnreadableMessageError, which becomes an
# `EDM:ERR:0003` response: a correspondent left without an answer learns
# nothing about what was wrong with what they sent.
class EvidenceRequestParser
  include SlotReading

  def initialize(document)
    @request = at(document, '/query:QueryRequest')
    raise UnreadableMessageError, I18n.t('parsers.evidence_request.not_a_query_request') if @request.nil?
  end

  def request_id = attribute(request, 'id')

  def procedure_code = slot_text('Procedure', request)

  def beneficiary
    person = slot_content('NaturalPerson', query, './sdg:Person')

    # Validated here rather than trusted: an incomplete person would otherwise
    # reach the templates, where `escape(nil)` renders an empty element — a
    # message that violates the specification instead of a failure that says so.
    NaturalPerson.new(
      eidas_identifier: text_at(person, './sdg:Identifier'),
      family_name: text_at(person, './sdg:FamilyName'),
      given_name: text_at(person, './sdg:GivenName'),
      date_of_birth: text_at(person, './sdg:DateOfBirth'),
    ).validate!(:request_beneficiary, error: UnreadableMessageError)
  end

  # The requester is the agent classified `ER`. OOTS-France, or its foreign
  # equivalent, travels in the same collection classified `IP`, and answering
  # the platform instead of the requester would address the wrong party.
  def requester
    agent = slot_elements('EvidenceRequester', request)
      .filter_map { |element| at(element, './sdg:Agent') }
      .find { |candidate| text_at(candidate, './sdg:Classification') == EvidenceRequester::REQUESTER }

    raise UnreadableMessageError, I18n.t('parsers.evidence_request.no_er_agent') if agent.nil?

    build_requester(agent)
  end

  def evidence_type
    described = slot_content('EvidenceRequest', query, './sdg:DataServiceEvidenceType')
    titles = all(described, './sdg:Title').to_h { |title| [attribute(title, 'lang'), title.text] }

    EvidenceType.new(
      id: require_content(text_at(described, './sdg:EvidenceTypeClassification'),
        'parsers.evidence_request.evidence_type_without_id'),
      descriptions: titles,
      distribution_format: text_at(described, './sdg:DistributedAs/sdg:Format'),
    )
  end

  private

  attr_reader :request

  def query
    @query ||= at(request, './query:Query') ||
               raise(UnreadableMessageError, I18n.t('parsers.evidence_request.no_query'))
  end

  def build_requester(agent)
    identifier = at(agent, './sdg:Identifier')
    name = at(agent, './sdg:Name')

    EvidenceRequester.new(
      # A SIRET is digits, and a reader that parsed numbers would drop its
      # leading zero. Read as text, always.
      id: require_content(identifier&.text, 'parsers.evidence_request.agent_without_id'),
      type_id: require_content(attribute(identifier, 'schemeID'), 'parsers.evidence_request.agent_without_scheme'),
      name: name&.text,
      language: attribute(name, 'lang'),
      # Read rather than defaulted: `Address` says `FR`, which is exactly the
      # wrong answer about a foreign requester.
      address: Address.new(country: agent_country(agent)),
    )
  end
end
