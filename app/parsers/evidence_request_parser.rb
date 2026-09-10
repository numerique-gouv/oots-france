# An `ExecuteQueryRequest` a foreign correspondent addressed to France.
#
# Everything it cannot read raises UnreadableMessageError, and so does
# everything `validate!` refuses — a request naming two evidence subjects is
# perfectly readable and still not one France may answer. Both become an
# `EDM:ERR:0003` response: a correspondent left without an answer learns
# nothing about what was wrong with what they sent.
class EvidenceRequestParser
  include SlotReading
  include AgentConformance
  include RequirementConformance

  # The slots chapter 4.6 counts under `query:QueryRequest`, each under the rule
  # that counts it. `= 1` is what the readers below cannot say: they fetch the
  # slot they need and refuse its absence naming no rule, where a second copy of
  # it would go unseen.
  #
  # Two of the counted slots are not here, and the endpoint of their refusal is
  # why: `EvidenceRequest` is counted under `query:Query` by `validate!`, and
  # `EvidenceRequester` where the requester is read, `R-EDM-REQ-S012` being a
  # refusal no answer can carry — where everything counted here goes back in an
  # `EDM:ERR:0003`.
  REQUIRED_SLOTS = {
    'SpecificationIdentifier' => 'R-EDM-REQ-S005',
    'IssueDateTime' => 'R-EDM-REQ-S006',
    'Procedure' => 'R-EDM-REQ-S007',
    'PossibilityForPreview' => 'R-EDM-REQ-S009',
    'ExplicitRequestGiven' => 'R-EDM-REQ-S010',
    'EvidenceProvider' => 'R-EDM-REQ-S013',
    'Requirements' => 'R-EDM-REQ-S011',
  }.freeze

  # `R-EDM-REQ-S004`, copied from the Schematron rather than tightened: the rule
  # constrains neither the version nibble nor the variant one, so a reader that
  # asked for RFC 4122 in full would refuse identifiers the specification
  # accepts.
  IDENTIFIER = /\Aurn:uuid:\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  # `R-EDM-REQ-C042` admits this value and no other. Its message adds that
  # `eidas2` « can be used for testing purposes until confirmation of provision
  # of a suitable legal basis », which its assertion does not: the assertion is
  # what plays.
  BENEFICIARY_SCHEME = 'eidas'.freeze

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
    require_slot('EvidenceRequest', 'R-EDM-REQ-S015', query)
    require_expected_specification
    require_one_evidence_subject
    require_requester_country
    require_conformant_accompanying_agents
    require_conformant_provider(provider_agent)
    require_beneficiary_identifier_scheme
    require_conformant_requirements

    self
  end

  # Refused here, at the read, and not among the checks of `validate!`: every
  # caller reads this attribute for its own reasons — `ChooseAnswer` before it
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

  # The requester is the one agent classified `ER`, `R-EDM-REQ-C074` counting
  # them. OOTS-France, or its foreign equivalent, travels in the same collection
  # classified `IP`, and answering the platform instead of the requester would
  # address the wrong party.
  def requester = build_requester(requester_agent)

  # What the requesting agent declares of itself, read without judging it.
  #
  # `requester` refuses an agent whose scheme, name or language breaks a FATAL
  # rule, and those refusals leave the correspondent no answer at all: the
  # journal is their only trace — see `docs/journal_des_echanges.md`, which
  # holds that a refusal whose reason is known and unrecorded cannot be
  # justified afterwards. The identifier and the country are read before any of
  # those checks and are usually perfectly valid, a name missing its `lang`
  # saying nothing about them, so the line that records the refusal keeps what
  # was there to read rather than losing it with the agent.
  #
  # Safe to keep where the answer is not: an `AuditEvent` is not a message, no
  # rule of the TDD judges it, and nothing echoes it back to anyone.
  def declared_requester_id = declared { |agent| at(agent, './sdg:Identifier')&.text.presence }

  def declared_requester_country = declared { |agent| agent_country(agent) }

  def evidence_type
    described = slot_content('EvidenceRequest', query, './sdg:DataServiceEvidenceType')
    titles = all(described, './sdg:Title').to_h { |title| [attribute(title, 'lang'), title.text] }

    EvidenceType.new(
      id: require_content(text_at(described, './sdg:EvidenceTypeClassification'),
        'parsers.evidence_request.evidence_type_without_id'),
      descriptions: titles,
      distribution_formats: requested_formats(described),
    )
  end

  private

  attr_reader :request

  # A collection that does not yield exactly one requester leaves nothing to
  # declare: `R-EDM-REQ-S012` and `C074` are what `requester_agent` itself
  # raises, and neither leaves an agent whose identifier or country could be
  # journalled as the requester's.
  def declared
    yield(requester_agent)
  rescue UnreadableMessageError
    nil
  end

  # `R-EDM-REQ-S012` counted here and not in `REQUIRED_SLOTS`: the count fails
  # where the requester is read, so the refusal carries no answer — as `C074`'s
  # does, and for the same reason. Read through `require_slot` all the same, so
  # that a second `EvidenceRequester` slot is refused rather than ignored by
  # `slot_elements`, which takes the first.
  def agents
    @agents ||= begin
      require_slot('EvidenceRequester', 'R-EDM-REQ-S012')

      slot_elements('EvidenceRequester', request).filter_map { |element| at(element, './sdg:Agent') }
    end
  end

  # `R-EDM-REQ-S042`: the slot value carries the agent itself, an `AnyValueType`
  # where the `EvidenceRequester` slot is a collection of `rim:Element`. The
  # first is taken when a request carries two — `S042` asserts one and `S043`
  # counts the children of the agent, so no assertion refuses the second, and
  # the `1..1` of chapter 4.5.1 §3.3 is prose alone.
  #
  # Read only once `REQUIRED_SLOTS` has counted the slot: `slot` refuses an
  # absent one without naming a rule, and an `EDM:ERR:0003` whose `detail` is
  # empty tells neither the correspondent nor the journal what was broken.
  def provider_agent
    agent = at(slot('EvidenceProvider', request), './rim:SlotValue/sdg:Agent')
    refuse('R-EDM-REQ-S042', 'parsers.evidence_request.provider_without_agent') if agent.nil?

    agent
  end

  def requester_agent = @requester_agent ||= sole_agent_classified_requester

  # `R-EDM-REQ-C074` counts the agents classified `ER` and asks for exactly one.
  # Counted at the read of the requester and not among the checks of
  # `validate!`, so that a count that fails takes the reading down with it:
  # everything the journal knows of the requester passes through here, and a
  # check standing beside would let the first of two agents be recorded as
  # though it had been read.
  #
  # The comparison is raw, as the rule's is — `sdg:Classification='ER'`, where
  # `C073` normalises. An agent classified ` ER ` therefore counts for none
  # here, and is refused by `C014`, which compares raw too and does answer.
  def sole_agent_classified_requester
    classified = agents.select { |agent| text_at(agent, './sdg:Classification') == EvidenceRequester::REQUESTER }
    return classified.first if classified.one?

    refuse('R-EDM-REQ-C074', 'parsers.evidence_request.requester_agent_not_alone', count: classified.size)
  end

  # `= 1` and not `>= 1`: the rules count the slot, and two of the same name
  # leave which one is meant undecided. The scope is where the rule counts:
  # `R-EDM-REQ-S015` counts `EvidenceRequest` among the children of
  # `query:Query`, every other one among those of `query:QueryRequest`.
  def require_slot(name, rule, scope = request)
    return if all(scope, "./rim:Slot[@name='#{name}']").one?

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

  # Refused among the checks of `validate!`, and not where the requester is
  # read: an error response carries no address for the agent it answers —
  # `ErrorResponseBuilder#requester_agent` renders neither address nor
  # classification — so nothing of what is refused here would travel back in it.
  # The refusal therefore becomes the `EDM:ERR:0003` a correspondent can learn
  # from, where the refusals of `build_requester` cannot.
  #
  # `R-EDM-REQ-C073` counts the elements whose `normalize-space` is not empty
  # and asks for exactly one, so a second address or a blank one breaks it as
  # much as none at all. `R-EDM-REQ-C015` then judges the value that is there,
  # exactly and case included: its assertion is an `=`, with no `i` flag.
  def require_requester_country
    declared = all(requester_agent, './sdg:Address/sdg:AdminUnitLevel1').reject { |code| code.text.squish.empty? }
    refuse('R-EDM-REQ-C073', 'parsers.evidence_request.agent_without_country') unless declared.one?

    country = declared.first.text
    return if CountryIdentificationCode.valid?(country)

    refuse('R-EDM-REQ-C015', 'parsers.evidence_request.agent_country_unknown', country:)
  end

  # `R-EDM-REQ-C041` and `C042`, whose context is the identifier of the person a
  # `NaturalPerson` slot names: they fire on the element and not on the slot, so
  # a request carrying no identifier at all breaks neither — chapter 2.1
  # §2.3.1.2 provides for an identity established in the requester's own
  # country. The organisation's identifiers are `C054` and `C055`, applied by
  # `legal_identifiers` and by `LegalPerson`.
  #
  # `nil?` and not `blank?` for the first: `C041` asserts the attribute's
  # presence, so one written empty satisfies it and falls to `C042`, which
  # compares the value.
  def require_beneficiary_identifier_scheme
    slot = find_slot('NaturalPerson', query)
    return if slot.nil?

    all(slot, './rim:SlotValue/sdg:Person/sdg:Identifier').each do |identifier|
      scheme = attribute(identifier, 'schemeID')
      refuse('R-EDM-REQ-C041', 'parsers.evidence_request.beneficiary_identifier_without_scheme') if scheme.nil?
      next if scheme == BENEFICIARY_SCHEME

      refuse('R-EDM-REQ-C042', 'parsers.evidence_request.beneficiary_scheme_unexpected',
        scheme:, expected: BENEFICIARY_SCHEME)
    end
  end

  # Every distribution the request names, and not the first alone:
  # `R-EDM-REQ-C032` counts `sdg:DistributedAs` and asks for one « at least », so
  # a correspondent asking for a structured format with a human-readable
  # fallback beside it — the case chapter 4.5.1 §3.5 names — is conformant.
  #
  # Counted where the rule counts them, and the formats read from them: a
  # `sdg:DistributedAs` naming no format keeps `C032`, and refusing the request
  # under that identifier would name it a rule it did not break.
  def requested_formats(described)
    distributions = all(described, './sdg:DistributedAs')
    refuse('R-EDM-REQ-C032', 'parsers.evidence_request.evidence_type_without_distribution') if distributions.empty?

    distributions.map { |distribution| text_at(distribution, './sdg:Format') }
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
  #
  # The level of assurance is read like the rest and refused when absent, where
  # a reader could have ignored an element France never echoes: `R-EDM-REQ-C036`
  # is FATAL, so a request that omits it is not one a correspondent may send.
  # The two optional attributes are read so that the journal of article 17
  # records the subject as it circulated, and not as this application would have
  # written it.
  def natural_person
    person = slot_content('NaturalPerson', query, './sdg:Person')

    NaturalPerson.new(
      level_of_assurance: text_at(person, './sdg:LevelOfAssurance'),
      eidas_identifier: text_at_without_leading_blanks(person, './sdg:Identifier'),
      family_name: text_at(person, './sdg:FamilyName'),
      given_name: text_at(person, './sdg:GivenName'),
      date_of_birth: normalised_text_at(person, './sdg:DateOfBirth'),
      place_of_birth: text_at(person, './sdg:PlaceOfBirth'),
      gender: text_at(person, './sdg:Gender'),
    ).validate!(:request_beneficiary, error: UnreadableMessageError)
  end

  # `R-EDM-REQ-C043` matches on `normalize-space(text())`, which trims both
  # ends, where `text_at` trims neither. `strip` and not a transposition of
  # `normalize-space`: a date the model accepts carries no inner blank, so
  # squeezing those would never change an outcome.
  def normalised_text_at(scope, path) = text_at(scope, path)&.strip

  # The head alone, because that is all `R-EDM-REQ-C040` and `C051` admit:
  # they carry no `^` but they do carry a `$`, so anything may precede the
  # identifier and nothing may follow it. Run against Saxon, the engine that
  # plays the rules, ` ES/AT/02635542Y` satisfies C040 and `ES/AT/02635542Y `
  # does not. Trimming the tail too would have France accept what a FATAL rule
  # refuses — the mirror of the over-strictness this reader exists to undo.
  #
  # What precedes is trimmed rather than tolerated: the rule admits any prefix
  # at all, `xxES/AT/02635542Y` included, and `EidasIdentified` deliberately
  # keeps its `\A` anchor against that. Blanks are the one prefix that carries
  # no claim, so they are removed rather than made to fail.
  #
  # Applied to the identifiers alone and not to every reading — no rule
  # normalises `sdg:FamilyName` or `sdg:LegalName`, which the journal of
  # article 17 must record exactly as they circulated.
  def text_at_without_leading_blanks(scope, path) = text_at(scope, path)&.lstrip

  # `R-EDM-REQ-S047`: the slot value carries an `sdg:LegalPerson` of the `p4s`
  # namespace. The symmetry with the person above stops at the slot: a natural
  # person travels in a request as `sdg:Person` and in a response as
  # `sdg:NaturalPerson`, where an organisation is an `sdg:LegalPerson` on both
  # sides.
  def legal_person
    organisation = slot_content('LegalPerson', query, './sdg:LegalPerson')

    LegalPerson.new(
      eidas_identifier: text_at_without_leading_blanks(organisation, './sdg:LegalPersonIdentifier'),
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

  # Everything refused here leaves the correspondent no answer at all, and that
  # is not a shortcoming: an `EDM:ERR:0003` names the requester by copying back
  # its identifier, its scheme, its name and the language of that name —
  # `ErrorResponseBuilder#requester_agent` through `_agent.xml.erb` — and
  # `R-EDM-ERR-C010`, `C009`, `C027`, `C028` and `C029` are FATAL on each of
  # them. Refusing a value by signing a message that carries it is not a
  # refusal. `sdg:Name` cannot be dropped either, `AgentType` making it
  # `minOccurs="1"`, and the scheme is the `type` of the ebMS `finalRecipient`,
  # which is the return address itself.
  #
  # `R-EDM-REQ-C011` and the chapter behind `AGENT_IDENTIFIER_REQUIRED` are
  # refused here for the same reason, one step earlier: an identifier a request
  # never carried, or one naming no scheme, is a value the answer would have to
  # copy back and has not got.
  #
  # `EvidenceProvision::RejectUnanswerableRequester` is where that silence is
  # journalled, as `RejectMalformedIdentifiers` journals the ebMS identifiers it
  # refuses for the same reason. What `validate!` refuses does go back.
  def build_requester(agent)
    identifier = require_agent_identifier(agent, :agent)
    # A SIRET is digits, and a reader that parsed numbers would drop its
    # leading zero. Read as text, always. Read after the rules above and not
    # before them: an identifier written empty breaks none of them — `C012`
    # measures a length no value is too short for — so the refusal that names
    # no rule comes last, once every rule that could have named one has passed.
    id = require_content(identifier.text, 'parsers.evidence_request.agent_without_id')

    name = at(agent, './sdg:Name')

    EvidenceRequester.new(
      id:, type_id: attribute(identifier, 'schemeID'),
      name: agent_name(name, :agent),
      language: require_language(name, :agent),
      # Read rather than defaulted: `Address` says `FR`, which is exactly the
      # wrong answer about a foreign requester.
      address: Address.new(country: agent_country(agent)),
    )
  end

  # Every agent of the `EvidenceRequester` collection that is not the requester
  # — the intermediary platform of the country that asks, in practice. Eight
  # FATAL rules of chapter 4.6 judge each agent of that collection: none of
  # their contexts carries a condition on the classification, where
  # `R-EDM-REQ-C073` alone narrows itself to `sdg:Agent[…sdg:Classification='ER']`.
  #
  # Refused among the checks of `validate!`, so these refusals do go back: an
  # error response names the requester alone — `ErrorResponseBuilder#requester_agent`
  # writes a single `sdg:Agent`, and the `R-EDM-ERR-*` rules judge that one — so
  # nothing of the agent refused here would travel in the message that refuses it.
  #
  # Selected by what they are not, the mirror of what `requester_agent` retains:
  # a classification written ` ER ` therefore satisfies `C013`, which
  # normalises, and breaks `C014`, which compares raw — as the Schematron does.
  def require_conformant_accompanying_agents
    agents.reject { |agent| text_at(agent, './sdg:Classification') == EvidenceRequester::REQUESTER }
      .each { |agent| require_conformant_agent(agent) }
  end
end
