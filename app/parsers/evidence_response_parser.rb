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

  # The two values `R-EDM-RESP-S006` allows: the evidence travels with the
  # response, or it is announced for later. Only the deferral is asked about by
  # the readings below — a response claiming success and carrying nothing stays
  # unreadable, which is what it is — where the rules ask about both.
  SUCCESS = 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Success'.freeze
  UNAVAILABLE = 'urn:oasis:names:tc:ebxml-regrep:ResponseStatusType:Unavailable'.freeze
  STATUSES = [SUCCESS, UNAVAILABLE].freeze

  # The slots `R-EDM-RESP-S009` to `-S013` require, each under its own rule and
  # each exactly once: the rules count them, and two of the same name leave
  # which one is meant undecided.
  REQUIRED_SLOTS = {
    'SpecificationIdentifier' => 'R-EDM-RESP-S009',
    'EvidenceResponseIdentifier' => 'R-EDM-RESP-S010',
    'IssueDateTime' => 'R-EDM-RESP-S011',
    'EvidenceProvider' => 'R-EDM-RESP-S012',
    'EvidenceRequester' => 'R-EDM-RESP-S013',
  }.freeze

  AVAILABLE_AT_SLOT = 'ResponseAvailableDateTime'.freeze
  AVAILABLE_AT = "./rim:Slot[@name='#{AVAILABLE_AT_SLOT}']/rim:SlotValue/rim:Value".freeze

  # What `R-EDM-RESP-S016` allows a response to be made of. The rule itself
  # compares two counts — the named children against every child — so what it
  # refuses can only be named by taking the complement, which is what
  # `unexpected_children` does.
  EXPECTED_CHILDREN = [*REQUIRED_SLOTS.keys, AVAILABLE_AT_SLOT]
    .map { |name| "./rim:Slot[@name='#{name}']" }
    .push('./rim:RegistryObjectList')
    .join(' | ').freeze

  # `R-EDM-RESP-S004`, copied from the Schematron rather than tightened: the
  # rule constrains neither the version nibble nor the variant one, so a reader
  # asking for RFC 4122 in full would report a violation the specification does
  # not state. Written out rather than borrowed from `EvidenceRequestParser`,
  # which holds the same shape for the other direction: what the two rules have
  # in common is the wording of the TDD, not a decision this repository takes
  # once. The response identifier, below, carries no prefix at all.
  REQUEST_IDENTIFIER = /\Aurn:uuid:\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  # `R-EDM-RESP-C004` and `-C005`, which hold the two date slots to one and the
  # same assertion — again as the rules match and not as `xsd:dateTime` defines:
  # they look for that shape and say nothing of the day being a real one, so
  # `2026-02-30T…` breaks neither and is reported under neither. Reading the
  # value is another matter — `response_available_at` refuses that date, because
  # it hands back a moment and no such moment exists.
  DATE_TIME = /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/

  def initialize(document)
    @response = at(document, '/query:QueryResponse')
    raise UnreadableMessageError, I18n.t('parsers.not_a_query_response') if @response.nil?
  end

  # The rules of chapter 4.6 a reader settles on the response alone — without a
  # schema, without a code list, and without correlating another message. All
  # `FATAL`, and none of them refused: the chapter assigns the duty of
  # validating to nobody and attaches no `EDM:ERR:*` code to a receiver, and
  # chapter 4.5.3 opens no error path from a portal back to a provider. Hence
  # `violations` and not `validate!` — nothing here raises, and a name in `!`
  # would invite the next reader to make it refuse.
  def violations
    [
      *missing_slots,
      unexpected_specification,
      *unexpected_status,
      deferral_without_date,
      date_without_deferral,
      malformed_request_id,
      malformed_response_id,
      malformed_issue_date,
      malformed_available_date,
      provider_without_ep_agent,
      *provider_identifiers_without_scheme,
      missing_object_list,
      exception_in_a_success,
      *unexpected_children,
    ].compact
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
  # The five other elements `R-EDM-RESP-S062` puts there — `IssuingDate`,
  # `IsAbout`, `IssuingAuthority`, `IsConformantTo`, `Distribution` — are not
  # read: that rule binds whoever *writes* a response, no chapter asks a
  # receiver to keep them, and chapter 4.8 does not count them among what an
  # evidence requester logs. Reading them would be inventing.
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

  # Where the rules count slots rather than look one up: `find_slot` stops at the
  # first, which is exactly the cardinality they are checking.
  def named_slots(name) = all(response, "./rim:Slot[@name='#{name}']")

  def missing_slots
    REQUIRED_SLOTS.filter_map do |name, rule|
      violation(rule, 'slot_required', name:) unless named_slots(name).one?
    end
  end

  def unexpected_specification
    within_slot('SpecificationIdentifier') do |declared|
      next if EdmSpecification.matches?(declared)

      violation('R-EDM-RESP-C002', 'unexpected_specification',
        announced: named(declared, 'absent_specification'), expected: EdmSpecification::IDENTIFIER)
    end
  end

  # `R-EDM-RESP-S005` requires the attribute, `-S006` restricts it to the two
  # values above — and an absent status breaks both, not just the first: XPath
  # compares a missing attribute as an empty node set, so `@status='…Success'`
  # is false there too. Reported as the Schematron reports it, each rule saying
  # what it alone requires.
  def unexpected_status
    declared = attribute(response, 'status')
    return [] if STATUSES.include?(declared)

    [
      (violation('R-EDM-RESP-S005', 'absent_status') if declared.nil?),
      violation('R-EDM-RESP-S006', 'unexpected_status', announced: named(declared, 'absent_value')),
    ]
  end

  # `R-EDM-RESP-S045` and `R-EDM-RESP-S014`, which are one another's converse:
  # the slot belongs to a deferral, once, and to nothing else.
  def deferral_without_date
    return if !unavailable? || named_slots(AVAILABLE_AT_SLOT).one?

    violation('R-EDM-RESP-S045', 'deferral_without_date', name: AVAILABLE_AT_SLOT)
  end

  def date_without_deferral
    return if unavailable? || named_slots(AVAILABLE_AT_SLOT).none?

    violation('R-EDM-RESP-S014', 'date_without_deferral', name: AVAILABLE_AT_SLOT)
  end

  # `R-EDM-RESP-S003` requires the attribute, `-S004` shapes it, and the two
  # never fire together. The context each hangs on is why: `-S004` is asserted
  # against the attribute node itself, so a response carrying no `@requestId`
  # gives it nothing to match and leaves it silent, while `-S003` is asserted
  # against the response, which is always there. One and the same `sch:rule`
  # carries `-S003` beside `-S005`.
  #
  # The status pair splits the other way round, both of it being asserted
  # against the response: an absent one breaks `-S005` and `-S006` together, a
  # wrong one breaks `-S006` alone, `-S005` asking only that the attribute be
  # there.
  def malformed_request_id
    declared = request_id&.strip
    return violation('R-EDM-RESP-S003', 'absent_request_id') if declared.nil?
    return if declared.match?(REQUEST_IDENTIFIER)

    violation('R-EDM-RESP-S004', 'request_id_not_a_uuid', id: named(declared, 'absent_value'))
  end

  # `R-EDM-RESP-C003`, on the bare UUID the slot carries — the `urn:uuid:`
  # prefix belongs to the attribute above and to nothing else here.
  def malformed_response_id
    within_slot('EvidenceResponseIdentifier') do |declared|
      next if declared.match?(Exchange::UUID)

      violation('R-EDM-RESP-C003', 'response_id_not_a_uuid', id: named(declared, 'absent_value'))
    end
  end

  def malformed_issue_date
    within_slot('IssueDateTime') do |declared|
      next if declared.match?(DATE_TIME)

      violation('R-EDM-RESP-C004', 'issue_date_not_a_date_time', value: named(declared, 'absent_date'))
    end
  end

  # `R-EDM-RESP-C005`, the twin of the above on the other date slot. Asked of any
  # response carrying it, and not of a deferral only: the rule hangs on the slot,
  # where `-S014` is what has something to say about a status that should not
  # carry it.
  def malformed_available_date
    within_slot(AVAILABLE_AT_SLOT) do |declared|
      next if declared.match?(DATE_TIME)

      violation('R-EDM-RESP-C005', 'available_date_not_a_date_time', value: named(declared, 'absent_date'))
    end
  end

  # `R-EDM-RESP-C046`: one agent classified `EP`, and one only — where
  # `#provider` takes the first it finds, the rule counts them.
  #
  # Asked of a slot that is there, and of its emptiness too, for the reason
  # `within_slot` gives: the rule hangs on the `rim:SlotValue`, so a slot
  # carrying none would otherwise break nothing at all.
  def provider_without_ep_agent
    found = find_slot('EvidenceProvider', response)
    return if found.nil?

    agents = all(found, "./rim:SlotValue/rim:Element/sdg:Agent[sdg:Classification='#{EvidenceProvider::PROVIDER}']")

    violation('R-EDM-RESP-C046', 'no_single_ep_agent') unless agents.one?
  end

  # `R-EDM-RESP-C006`: every identifier of an agent in that slot names the scheme
  # it belongs to. Reported for each one that does not, which is what the rule
  # asserts — it hangs on the identifier, not on the slot.
  #
  # No tension with `#provider`, which hands back an identity as read and never
  # validated: nothing here refuses, so naming the rule refuses no reading.
  #
  # Absent and not blank: the rule asserts `@schemeID`, which XPath answers on
  # the attribute node alone, so `schemeID=""` satisfies it. Asking `present?`
  # would report a violation the rule does not state, and the journal would
  # accuse a correspondent of a breach the Schematron clears.
  def provider_identifiers_without_scheme
    all(response, "./rim:Slot[@name='EvidenceProvider']/rim:SlotValue/rim:Element/sdg:Agent/sdg:Identifier")
      .select { |identifier| attribute(identifier, 'schemeID').nil? }
      .map { |identifier| violation('R-EDM-RESP-C006', 'provider_identifier_without_scheme', id: identifier.text) }
  end

  # `R-EDM-RESP-S007`, which `-S016` does not cover: that one forbids the
  # children a response may not have, this one requires the object list it must
  # have — an answer carrying no document still declares the package it carries
  # nothing in.
  def missing_object_list
    return if at(response, './rim:RegistryObjectList')

    violation('R-EDM-RESP-S007', 'no_object_list')
  end

  # `R-EDM-RESP-S008`. The assertion published with the chapter holds only where
  # an `rs:Exception` contains another one, its test being evaluated against the
  # exception itself — so what is applied here is what the rule says: an answer
  # that succeeded carries no exception. A deferral that carries one is caught
  # all the same, by `-S016`, which counts every child.
  def exception_in_a_success
    return unless attribute(response, 'status') == SUCCESS
    return if at(response, './rs:Exception').nil?

    violation('R-EDM-RESP-S008', 'exception_in_a_success')
  end

  def unexpected_children
    (all(response, './*') - all(response, EXPECTED_CHILDREN)).map do |child|
      violation('R-EDM-RESP-S016', 'unexpected_child', name: child_name(child))
    end
  end

  # A slot by its `@name` rather than by its element name, which is `Slot` for
  # every one of them and would name nothing.
  def child_name(child)
    attribute(child, 'name') || [child.namespace&.prefix, child.name].compact.join(':')
  end

  # A rule about content speaks only of a slot that is there: its absence is
  # already said by the rule requiring it, and naming it twice would read as two
  # breaches where there is one. A slot present and empty is reported here all
  # the same — the Schematron hangs those assertions on the value element, so an
  # empty slot would otherwise carry nothing and break no rule.
  def within_slot(name)
    found = find_slot(name, response)

    yield(text_at(found, './rim:SlotValue/rim:Value').to_s.strip) if found
  end

  # What a sentence puts where a value should have been, agreeing with what it
  # names.
  def named(declared, key) = declared.presence || I18n.t("parsers.evidence_response.#{key}")

  def violation(rule, key, **)
    BusinessRuleViolation.new(rule:, description: I18n.t("parsers.evidence_response.#{key}", **))
  end

  def build_provider(agent)
    identifier = at(agent, './sdg:Identifier')

    EvidenceProvider.new(
      identifier: EbmsIdentity.new(id: identifier&.text, type_id: attribute(identifier, 'schemeID')),
      address: Address.new(country: agent_country(agent)),
    )
  end
end
