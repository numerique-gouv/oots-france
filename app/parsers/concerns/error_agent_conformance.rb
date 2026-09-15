# What chapter 4.6 asks of the two `sdg:Agent` a received error report names:
# the one the `ErrorProvider` slot carries, which is the party that failed, and
# the one the `EvidenceRequester` slot carries, which is the party that asked.
#
# Four rules judge them both, written twice in the Schematron under two
# identifiers each — the slot fixes those, never the classification. What the
# provider alone owes is its classification, its address and the territory in
# it: the requester's slot has no counterpart, chapter 4.5.3 §3.2 allowing that
# agent no classification at all.
#
# Read and never refused, like every rule this parser confronts a report to:
# `ErrorResponseParser#violations` says why.
#
# One sentence per rule and not one per slot, where `AgentConformance` has one
# of each: there the three agents of a request are called three different
# things in French — the requester, the platform beside it, the designated
# provider — and here both are « the agent of slot X », the slot being the only
# thing that tells them apart.
#
# Apart from the parser, as the four conformance modules beside it are, and for
# the reason `ErrorEnvelopeConformance` states.
#
# `declared_response`, `specification`, `violation` and `named` are the
# includer's.
module ErrorAgentConformance
  include OotsNamespaces

  # The four rules each slot publishes its own identifiers for. `C003`, `C004`,
  # `C031` and `C030` judge the error provider's agent; `C009`, `C010`, `C029`
  # and `C028` are those four assertions again, written word for word the same
  # over the requester's slot.
  #
  # Beside them, what chapter 4.5.3 requires to be there at all and no FATAL
  # assertion executes: each of these contexts is the element or below, so an
  # agent carrying no identifier and no name breaks no assertion. The detail
  # names the source that does, as `AgentConformance::AGENT_NAME_REQUIRED` does
  # for the request, and the subsection rather than the chapter — an operator
  # reading the journal has to be able to open it.
  SLOT_RULES = {
    'ErrorProvider' => {
      scheme: 'R-EDM-ERR-C003', identifier: 'R-EDM-ERR-C004',
      language: 'R-EDM-ERR-C031', language_code: 'R-EDM-ERR-C030',
      identifier_required: 'TDD 4.5.3 §3.1: ErrorProvider agent identifier required',
      name_required: 'TDD 4.5.3 §3.1: ErrorProvider agent name required',
    }.freeze,
    'EvidenceRequester' => {
      scheme: 'R-EDM-ERR-C009', identifier: 'R-EDM-ERR-C010',
      language: 'R-EDM-ERR-C029', language_code: 'R-EDM-ERR-C028',
      identifier_required: 'TDD 4.5.3 §3.2: EvidenceRequester agent identifier required',
      name_required: 'TDD 4.5.3 §3.2: EvidenceRequester agent name required',
    }.freeze,
  }.freeze

  PROVIDER_SLOT = 'ErrorProvider'.freeze

  # `C023` and `-S026`, mot pour mot the same assertion on the same context, and
  # both named: each is a rule the chapter publishes under its own identifier,
  # and nothing says which to keep quiet about. The one equivalent pair of the
  # request, `C102` and `C023`, names one of the two because the context of
  # `C102` is the narrower — which is not the case here.
  PROVIDER_AGENT_RULES = %w[R-EDM-ERR-C023 R-EDM-ERR-S026].freeze

  # Chapter 4.5.3 §3.2, whose table makes the requester's `sdg:Agent` `1..1`:
  # no assertion counts it, where the provider's is counted by the two above.
  REQUESTER_AGENT_SINGLE = 'TDD 4.5.3 §3.2: EvidenceRequester slot agent 1..1'.freeze

  # Chapter 4.5.3 §3.1, whose table makes the provider's `sdg:Address` `1..1`.
  # Named on the 1.2 line alone: `C024` requires it there in 2.0, and a rule and
  # a chapter saying the same thing would read as two breaches where there is
  # one.
  PROVIDER_ADDRESS_SINGLE = 'TDD 4.5.3 §3.1: ErrorProvider agent address 1..1'.freeze

  # The `AgentClassification` code list, and the three of its four codes `C008`
  # asks the error provider to carry: `ER` is struck out, this transaction
  # naming the party that failed and not the party that asked.
  AGENT_CLASSIFICATIONS = %w[ER IP EP ERRP].freeze
  ERROR_CLASSIFICATIONS = %w[EP IP ERRP].freeze

  private

  def agent_violations
    return [] if declared_response.nil?

    [
      *SLOT_RULES.flat_map { |slot, rules| judged_slot(slot, rules) },
      *agents_of(PROVIDER_SLOT).flat_map { |agent| judged_provider(agent) },
    ]
  end

  def judged_slot(slot, rules)
    [
      *agent_cardinality(slot),
      *agents_of(slot).flat_map { |agent| judged_agent(agent, slot, rules) },
    ]
  end

  def judged_agent(agent, slot, rules)
    [*agent_identifiers(agent, slot, rules), *agent_names(agent, slot, rules)]
  end

  # `C023` and `-S026` over the provider's slot value, the chapter over the
  # requester's. Both count the agent, and both are silent where the slot itself
  # is missing: `-S011` is what requires the first, chapter 4.5.3 §2 the second.
  def agent_cardinality(slot)
    all(declared_response, "./rim:Slot[@name='#{slot}']/rim:SlotValue")
      .reject { |value| all(value, './sdg:Agent').one? }
      .flat_map { rules_of(slot).map { |rule| violation(rule, 'slot_without_one_agent', slot:) } }
  end

  def rules_of(slot) = slot == PROVIDER_SLOT ? PROVIDER_AGENT_RULES : [REQUESTER_AGENT_SINGLE]

  # `C003` and `C009` assert the attribute's presence and nothing more, so one
  # written empty satisfies them and falls to `C004` and `C010`, which compare
  # the value — the shape the request's `C011` and `C012` take.
  #
  # `C004` and `C010` hold two things in one assertion: the scheme is of one of
  # the forms `IdentifierScheme.agent_scheme?` reads — `EEA_Country` on the 1.2
  # line, which publishes the very same thirty-one codes as `OOTS_Country` — and
  # the identifier stays under 256 characters, `string-length(.)` measuring the
  # element and not the attribute.
  def agent_identifiers(agent, slot, rules)
    identifiers = all(agent, './sdg:Identifier')
    return [violation(rules.fetch(:identifier_required), 'agent_without_identifier', slot:)] if identifiers.empty?

    identifiers.flat_map { |identifier| judged_identifier(identifier, slot, rules) }
  end

  def judged_identifier(identifier, slot, rules)
    scheme = attribute(identifier, 'schemeID')
    return [violation(rules.fetch(:scheme), 'agent_identifier_without_scheme', slot:)] if scheme.nil?

    [unknown_scheme(scheme, slot, rules), overlong_identifier(identifier, slot, rules)]
  end

  def unknown_scheme(scheme, slot, rules)
    return if IdentifierScheme.agent_scheme?(scheme)

    violation(rules.fetch(:identifier), 'agent_scheme_unknown', slot:, scheme: named(scheme, 'absent_value'))
  end

  def overlong_identifier(identifier, slot, rules)
    length = identifier.text.length
    return if length < AgentConformance::MAXIMUM_IDENTIFIER_LENGTH

    violation(rules.fetch(:identifier), 'agent_id_too_long', slot:, length:,
      maximum: AgentConformance::MAXIMUM_IDENTIFIER_LENGTH)
  end

  # `C031` and `C029` assert `@lang`, `C030` and `C028` then compare its raw
  # value to the code list — `.=$code` carrying no `i` flag and the list
  # publishing upper case, so `lang="fr"` breaks the second where `lang="FR"`
  # does not. Every name is judged, all four contexts being the element or its
  # attribute, and an agent carrying none breaks no assertion — which is why
  # that one names the chapter.
  def agent_names(agent, slot, rules)
    names = all(agent, './sdg:Name')
    return [violation(rules.fetch(:name_required), 'agent_without_name', slot:)] if names.empty?

    names.flat_map { |name| judged_name(name, slot, rules) }
  end

  def judged_name(name, slot, rules)
    language = attribute(name, 'lang')
    return [violation(rules.fetch(:language), 'agent_name_without_language', slot:)] if language.nil?
    return [] if LanguageCode.valid?(language)

    [violation(rules.fetch(:language_code), 'agent_language_unknown', slot:, language: named(language, 'absent_value'))]
  end

  # What the error provider's agent owes beside the four above, and the
  # requester's does not: chapter 4.5.3 §3.2 allows that one no classification
  # — « No classification allowed for sdg:Agent in Error Response for rim:Slot
  # "EvidenceRequester" » — in prose, its table carrying no such row, and no
  # assertion executes the prohibition.
  def judged_provider(agent)
    [
      missing_classification(agent),
      unexpected_classification(agent),
      *provider_address_violations(agent),
      *unknown_countries(agent),
      *unknown_territories(agent),
    ]
  end

  # `C007` normalises before asking that the classification not be empty, so an
  # absent element and a blank one break it alike.
  def missing_classification(agent)
    return if text_at(agent, './sdg:Classification').to_s.squish.present?

    violation('R-EDM-ERR-C007', 'provider_without_classification')
  end

  # `C008`, one assertion holding two things: the classification is of the
  # `AgentClassification` list, and it carries one of the three codes an error
  # report may name. The second half `matches` rather than compares, which is a
  # substring test, its pattern carrying no anchor.
  def unexpected_classification(agent)
    declared = text_at(agent, './sdg:Classification').to_s
    return if AGENT_CLASSIFICATIONS.include?(declared) && ERROR_CLASSIFICATIONS.any? { |code| declared.include?(code) }

    violation('R-EDM-ERR-C008', 'provider_classification_unexpected',
      classification: named(declared, 'absent_value'), expected: ERROR_CLASSIFICATIONS.join(', '))
  end

  # `C024`, which the two lines anchor differently: 2.0 asserts of the agent
  # that it carries one address and one country inside it, where 1.2 asserts of
  # the address that it carries one country — an agent naming no address at all
  # breaking nothing there. What the earlier line leaves unsaid, chapter 4.5.3
  # §3.1 says, its table making the address `1..1`.
  def provider_address_violations(agent)
    return earlier_line_address_violations(agent) unless specification.error_address_on_the_agent?
    return [] if all(agent, './sdg:Address').one? && all(agent, './sdg:Address/sdg:AdminUnitLevel1').one?

    [violation('R-EDM-ERR-C024', 'provider_without_one_address')]
  end

  def earlier_line_address_violations(agent)
    addresses = all(agent, './sdg:Address')

    [
      (violation(PROVIDER_ADDRESS_SINGLE, 'provider_without_one_address') unless addresses.one?),
      *addresses.reject { |address| all(address, './sdg:AdminUnitLevel1').one? }
        .map { violation('R-EDM-ERR-C024', 'address_without_one_country') },
    ]
  end

  # `C005`, whose context is the `sdg:AdminUnitLevel1` element: every one is
  # judged, none is required here, and the comparison is exact, the assertion
  # carrying neither `i` flag nor `normalize-space`.
  def unknown_countries(agent)
    all(agent, './sdg:Address/sdg:AdminUnitLevel1').filter_map do |declared|
      next if CountryIdentificationCode.valid?(declared.text)

      violation('R-EDM-ERR-C005', 'provider_country_unknown', country: named(declared.text, 'absent_value'))
    end
  end

  # `C006`, the counterpart of `C005` on the territory below the country.
  # Opposed to both lines though the 1.2.5 Schematron does not execute it: the
  # 4.6 of that tag publishes it FATAL all the same, and `docs/versions_tdd.md`
  # holds the doctrine — `R-EDM-REQ-C016` is the rule it was first settled on.
  def unknown_territories(agent)
    all(agent, './sdg:Address/sdg:AdminUnitLevel2').filter_map do |declared|
      next if NutsCode.valid?(declared.text)

      violation('R-EDM-ERR-C006', 'provider_territory_unknown', territory: named(declared.text, 'absent_value'))
    end
  end

  def agents_of(slot) = all(declared_response, "./rim:Slot[@name='#{slot}']/rim:SlotValue/sdg:Agent")
end
