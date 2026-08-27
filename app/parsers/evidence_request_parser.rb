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

  # `R-EDM-REQ-S016` lets the subject be a person or an organisation, and the
  # slot the request carries says which. A request carrying both is refused by
  # `validate!` before anything answers it, so the order here only decides what
  # a journal line shows of a message nothing will reply to — and it can show
  # nothing at all: a malformed `LegalPerson` slot raises where a well-formed
  # `NaturalPerson` sat beside it, and `AuditTrail#readable` drops the field.
  # Falling back on the other slot would only move the loss, no order sparing
  # both, and would answer a message the rule refuses in a way no chapter names.
  def beneficiary
    find_slot('LegalPerson', query) ? legal_person : natural_person
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

  # Validated here rather than trusted: an incomplete person would otherwise
  # reach the templates, where `escape(nil)` renders an empty element — a
  # message that violates the specification instead of a failure that says so.
  def natural_person
    person = slot_content('NaturalPerson', query, './sdg:Person')

    NaturalPerson.new(
      eidas_identifier: text_at(person, './sdg:Identifier'),
      family_name: text_at(person, './sdg:FamilyName'),
      given_name: text_at(person, './sdg:GivenName'),
      date_of_birth: text_at(person, './sdg:DateOfBirth'),
    ).validate!(:request_beneficiary, error: UnreadableMessageError)
  end

  # `R-EDM-REQ-S047`: the slot value carries an `sdg:LegalPerson` of the `p4s`
  # namespace. The symmetry with the person above stops at the slot: a natural
  # person travels in a request as `sdg:Person` and in a response as
  # `sdg:NaturalPerson`, where an organisation is an `sdg:LegalPerson` on both
  # sides.
  def legal_person
    organisation = slot_content('LegalPerson', query, './sdg:LegalPerson')

    LegalPerson.new(
      eidas_identifier: text_at(organisation, './sdg:LegalPersonIdentifier'),
      legal_name: text_at(organisation, './sdg:LegalName'),
      identifiers: legal_identifiers(organisation),
    ).validate!(:request_legal_person, error: UnreadableMessageError)
  end

  # The optional identifiers of chapter 4.5.1 — nought or more, no rule
  # numbering that cardinality — keyed by the scheme `R-EDM-REQ-C054` requires
  # each of them to name. One naming none is refused rather than filed under a
  # nil key, where it would designate nothing. That the scheme is one the code
  # list publishes is `LegalPerson`'s to say, `R-EDM-REQ-C055` being fatal.
  #
  # Two identifiers of one scheme leave only the last, and that is deliberate:
  # `R-EDM-REQ-C054` asserts the attribute's presence and nothing more, the
  # schema admitting `maxOccurs="unbounded"`, so such a request is conformant
  # and refusing it would invent a rule. What is lost is a column of the
  # journal — `regrep_body` keeps the message whole, and the response echoes
  # none of these identifiers, `R-EDM-RESP-S042` admitting only the eIDAS one
  # and the legal name.
  def legal_identifiers(organisation)
    all(organisation, './sdg:Identifier').to_h do |identifier|
      scheme = require_content(attribute(identifier, 'schemeID'),
        'parsers.evidence_request.legal_identifier_without_scheme')

      [scheme, identifier.text]
    end
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
