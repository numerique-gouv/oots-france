# An `ExecuteQueryRequest` a foreign correspondent addressed to France.
#
# Everything it cannot read raises UnreadableMessageError, and so does
# everything `validate!` refuses — a request naming two evidence subjects is
# perfectly readable and still not one France may answer. Both become an
# `EDM:ERR:0003` response: a correspondent left without an answer learns
# nothing about what was wrong with what they sent.
class EvidenceRequestParser
  include SlotReading

  # The slots chapter 4.6 makes mandatory that nothing else here would notice
  # missing, each under the rule that requires it. `Procedure`, `Requirements`
  # and the rest are demanded by the readers below, which raise on their own.
  REQUIRED_SLOTS = {
    'SpecificationIdentifier' => 'R-EDM-REQ-S005',
    'PossibilityForPreview' => 'R-EDM-REQ-S009',
    'ExplicitRequestGiven' => 'R-EDM-REQ-S010',
  }.freeze

  # `R-EDM-REQ-S004`, copied from the Schematron rather than tightened: the rule
  # constrains neither the version nibble nor the variant one, so a reader that
  # asked for RFC 4122 in full would refuse identifiers the specification
  # accepts.
  IDENTIFIER = /\Aurn:uuid:\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  def initialize(document)
    @request = at(document, '/query:QueryRequest')
    raise UnreadableMessageError, I18n.t('parsers.evidence_request.not_a_query_request') if @request.nil?
  end

  # The business rules of chapter 4.6 France settles before answering at all —
  # those a reader can decide without a schema. Each raises under its own
  # identifier, which travels to the `detail` of the `EDM:ERR:0003` the
  # correspondent receives.
  #
  # Checked here and not by Schematron: chapter 4.6 assigns the duty of
  # validating to nobody and presents its Schematrons as a way to prove
  # instances correct, which is what they still do on the messages this
  # repository produces.
  def validate!
    REQUIRED_SLOTS.each { |name, rule| require_slot(name, rule) }
    require_expected_specification
    require_one_evidence_subject

    self
  end

  # Refused here, at the read, and not among the checks of `validate!`: every
  # caller reads this attribute for its own reasons — `AnswerRequest` before it
  # validates anything, `AuditTrail` without ever validating — and an identifier
  # that breaks `R-EDM-REQ-S004` must reach none of them.
  #
  # What is at stake is the answer, not the request: `R-EDM-RESP-S004` and
  # `R-EDM-ERR-S004` hold `@requestId` to the same shape, so echoing back what
  # was received would have France sign a response that breaks a fatal rule.
  # An absent attribute is refused the same way, having nothing to echo at all.
  def request_id
    identifier = attribute(request, 'id').to_s.strip
    return identifier if identifier.match?(IDENTIFIER)

    refuse('R-EDM-REQ-S004', 'parsers.evidence_request.request_id_not_a_uuid',
      id: identifier.presence || I18n.t('parsers.evidence_request.unnamed_request_id'))
  end

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

  # `= 1` and not `>= 1`: the rules count the slot, and two of the same name
  # leave which one is meant undecided.
  def require_slot(name, rule)
    return if all(request, "./rim:Slot[@name='#{name}']").one?

    refuse(rule, 'parsers.evidence_request.slot_required', name:)
  end

  def require_expected_specification
    declared = text_at(request, "./rim:Slot[@name='SpecificationIdentifier']/rim:SlotValue/rim:Value")
    return if EdmSpecification.matches?(declared)

    refuse('R-EDM-REQ-C001', 'parsers.evidence_request.unexpected_specification',
      announced: declared.presence || I18n.t('parsers.evidence_request.unnamed_specification'),
      expected: EdmSpecification::IDENTIFIER)
  end

  # R-EDM-REQ-S016: either a natural person or a legal one, and never both.
  def require_one_evidence_subject
    declared = all(query, "./rim:Slot[@name='NaturalPerson']").size +
               all(query, "./rim:Slot[@name='LegalPerson']").size
    return if declared == 1

    refuse('R-EDM-REQ-S016', 'parsers.evidence_request.evidence_subject_not_alone', count: declared)
  end

  def refuse(rule, key, **)
    raise UnreadableMessageError.new(I18n.t(key, **), detail: rule)
  end

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
