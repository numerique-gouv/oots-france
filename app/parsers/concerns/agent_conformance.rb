# What chapter 4.6 asks of an `sdg:Agent` of a received request: its identifier,
# the scheme that identifier names, its names and the language of each. None of
# these rules narrows its context to a classification — `R-EDM-REQ-C073`, which
# does, is therefore not here — so the same reading serves the agent classified
# `ER`, the ones beside it, and the provider the request designates.
#
# Each reading takes a `wording` naming the agent it judges, which it cannot
# know itself: one rule refuses the requester, the platform beside it and the
# provider in three different French sentences, and `RULES` says under which
# identifier that rule is published for each. `require_conformant_agent` walks
# the agents the requester is not, which is where `C013`, `C014` and `C011` are
# applied today — the requester's own reading being `EvidenceRequestParser#build_requester`,
# which refuses without answering for what an error response would copy back.
#
# Refusals go through `refuse`, which the parser including this defines: naming
# the broken rule and turning it into an `UnreadableMessageError` is one act for
# every rule of the chapter, agent or not, and belongs where the rest of them
# are refused.
module AgentConformance
  include OotsNamespaces

  # `R-EDM-REQ-C012` measures 256 characters on the identifier itself — its
  # assertion reads `string-length(.)`, the context being `sdg:Identifier` —
  # where its prose names the `schemeID`. Held to the assertion: applied to the
  # scheme the clause would be dead, a long scheme already failing the exact
  # comparison to a code of the list.
  MAXIMUM_IDENTIFIER_LENGTH = 256

  # Chapter 4.5.1 §3.2 — the requesting agent's own subsection, §3.3 describing
  # the provider — makes `sdg:Name` `1..n`, and `AgentType` carries
  # `minOccurs="1"`. No Schematron rule asserts that absence, so the detail
  # names the source that does — as `ChooseAnswer::REPLAYED_IDENTIFIER` names
  # chapter 4.4 for a duty stated in prose alone. It reaches an operator
  # through the journal, which is this refusal's only trace.
  AGENT_NAME_REQUIRED = 'TDD 4.5.1 §3.2: EvidenceRequester agent name required'.freeze

  # The same silence over an absent identifier: the context of
  # `R-EDM-REQ-C011` is `sdg:Identifier` itself, so an agent carrying none
  # breaks no assertion, where `AgentType` declares it without `minOccurs` and
  # therefore requires it.
  AGENT_IDENTIFIER_REQUIRED = 'TDD 4.5.1 §3.2: EvidenceRequester agent identifier required'.freeze

  # The same two silences over the provider, and the same source filling them:
  # §3.3 — « Evidence Provider slot and example » — makes `Agent` `1..1`,
  # `Identifier` `1..1` and `Name` `1..n`, and `AgentType` carries the last two.
  # The subsection is named rather than the chapter, an operator reading the
  # journal having to be able to open it.
  PROVIDER_NAME_REQUIRED = 'TDD 4.5.1 §3.3: EvidenceProvider agent name required'.freeze

  PROVIDER_IDENTIFIER_REQUIRED = 'TDD 4.5.1 §3.3: EvidenceProvider agent identifier required'.freeze

  # What the readers below refuse, under the identifier each rule is published
  # by for the agent being judged. The slot fixes that identifier and never the
  # classification: `C011`, `C012`, `C109` and `C108` judge every agent of the
  # `EvidenceRequester` collection, and `C017`, `C018`, `C111` and `C110` are
  # those four assertions again, written word for word the same over the
  # provider's slot.
  REQUESTER_COLLECTION_RULES = {
    identifier: 'R-EDM-REQ-C012', language: 'R-EDM-REQ-C109', language_code: 'R-EDM-REQ-C108',
  }.freeze

  # The requester carries only those three. `EvidenceRequestParser#build_requester`
  # reads its identifier and its names itself — refusing without naming a rule,
  # since no answer could carry them — so the walk below never judges it, and
  # `fetch` says so loudly should that ever change.
  RULES = {
    agent: REQUESTER_COLLECTION_RULES,
    platform: REQUESTER_COLLECTION_RULES.merge(
      identifier_required: AGENT_IDENTIFIER_REQUIRED, scheme: 'R-EDM-REQ-C011', name_required: AGENT_NAME_REQUIRED,
    ).freeze,
    provider: {
      identifier: 'R-EDM-REQ-C018', language: 'R-EDM-REQ-C111', language_code: 'R-EDM-REQ-C110',
      identifier_required: PROVIDER_IDENTIFIER_REQUIRED, scheme: 'R-EDM-REQ-C017',
      name_required: PROVIDER_NAME_REQUIRED,
    }.freeze,
  }.freeze

  private

  # `R-EDM-REQ-C012`, `C018` on the provider, one assertion holding two things
  # either way: the scheme is of one of the forms `IdentifierScheme.agent_scheme?`
  # reads, and the identifier stays under 256 characters. Both refusals name the
  # rule; the wording says which half broke, since the correspondent learns
  # nothing else.
  #
  def require_known_agent_scheme(scheme, id, wording)
    rule = RULES.fetch(wording).fetch(:identifier)
    refuse(rule, "parsers.evidence_request.#{wording}_scheme_unknown", scheme:) unless IdentifierScheme.agent_scheme?(scheme)
    return if id.length < MAXIMUM_IDENTIFIER_LENGTH

    refuse(rule, "parsers.evidence_request.#{wording}_id_too_long",
      length: id.length, maximum: MAXIMUM_IDENTIFIER_LENGTH)
  end

  # `R-EDM-REQ-C092` measures `normalize-space(.)` and asks for more than one
  # character, which is why the value is squished rather than merely stripped:
  # ` A ` is one character to the rule.
  def agent_name(name, wording)
    refuse(AGENT_NAME_REQUIRED, "parsers.evidence_request.#{wording}_without_name") if name.nil?
    return name.text if name.text.squish.length > 1

    refuse('R-EDM-REQ-C092', "parsers.evidence_request.#{wording}_name_too_short", name: name.text)
  end

  # `R-EDM-REQ-C109`, `C111` on the provider, asserts `not(normalize-space(@lang)='')`,
  # so an attribute absent and one written blank break it alike. `R-EDM-REQ-C108`,
  # `C110` on the provider, then compares the raw value to the code list,
  # `.=$code` carrying no `i` flag and the list publishing upper case:
  # `lang="fr"` breaks it where `lang="FR"` does not, and so does ` FR `, which
  # the first rule accepts.
  def agent_language(name, wording)
    rules = RULES.fetch(wording)
    language = attribute(name, 'lang')
    refuse(rules.fetch(:language), "parsers.evidence_request.#{wording}_without_language") if language.to_s.squish.empty?
    return language if LanguageCode.valid?(language)

    refuse(rules.fetch(:language_code), "parsers.evidence_request.#{wording}_language_unknown", language:)
  end

  # In this order because refusing on the first breach imposes one, and no rule
  # fixes it: an agent that reaches the checks below has passed `C014`, so it is
  # an intermediary platform, and the sentences that refuse it may say so.
  def require_conformant_agent(agent)
    require_agent_classification(agent)
    require_agent_identifier(agent, :platform)
    require_agent_names(agent)
    require_agent_country(agent)
  end

  # `R-EDM-REQ-C013` normalises before asking that the classification not be
  # empty, so an absent element and a blank one break it alike. `C014` then
  # compares the raw value to `EvidenceRequester::CLASSIFICATIONS`, its `satisfies`
  # carrying no `i` flag and its context being the element, which is why it says
  # nothing of an agent that has none.
  def require_agent_classification(agent)
    classification = text_at(agent, './sdg:Classification')
    refuse('R-EDM-REQ-C013', 'parsers.evidence_request.platform_without_classification') if classification.to_s.squish.empty?
    return if EvidenceRequester::CLASSIFICATIONS.include?(classification)

    refuse('R-EDM-REQ-C014', 'parsers.evidence_request.platform_classification_unexpected', classification:)
  end

  # `R-EDM-REQ-C011`, `C017` over the provider's slot, asserts the attribute's
  # presence and nothing more, so one written empty satisfies it and falls to
  # `C012` — `C018` — which compares the value: the shape `C041` and `C042` take
  # on the beneficiary's identifier.
  def require_agent_identifier(agent, wording)
    rules = RULES.fetch(wording)
    identifier = at(agent, './sdg:Identifier')
    refuse(rules.fetch(:identifier_required), "parsers.evidence_request.#{wording}_without_identifier") if identifier.nil?

    scheme = attribute(identifier, 'schemeID')
    refuse(rules.fetch(:scheme), "parsers.evidence_request.#{wording}_without_scheme") if scheme.nil?

    require_known_agent_scheme(scheme, identifier.text, wording)
  end

  # Every `sdg:Name` the agent carries, and not the first alone: `AgentType`
  # makes them `1..n`, and the contexts of `C092`, `C109`/`C111` and
  # `C108`/`C110` are the name element and its attribute, so each name is judged
  # on its own. An agent carrying none breaks no assertion, all three contexts
  # being the element or below, which is why that refusal names the chapter.
  def agent_names(agent, wording)
    names = all(agent, './sdg:Name')
    refuse(RULES.fetch(wording).fetch(:name_required), "parsers.evidence_request.#{wording}_without_name") if names.empty?

    names
  end

  def require_agent_names(agent)
    agent_names(agent, :platform).each do |name|
      agent_name(name, :platform)
      agent_language(name, :platform)
    end
  end

  # `R-EDM-REQ-C015` alone, and no address required: `C073` is what demands one,
  # and it narrows itself to the agent classified `ER`. Every `sdg:AdminUnitLevel1`
  # is judged — that element is the rule's context — and compared exactly, its
  # assertion being an `=` with no `i` flag.
  def require_agent_country(agent)
    all(agent, './sdg:Address/sdg:AdminUnitLevel1').each do |declared|
      country = declared.text
      next if CountryIdentificationCode.valid?(country)

      refuse('R-EDM-REQ-C015', 'parsers.evidence_request.platform_country_unknown', country:)
    end
  end

  # What the agent of the `EvidenceProvider` slot owes, and all of it: no
  # classification, chapter 4.5.1 §3.3 asking for none, and no address, which is
  # `R-EDM-REQ-C073`'s to require of the agent classified `ER` alone.
  def require_conformant_provider(agent)
    require_agent_identifier(agent, :provider)
    require_provider_names(agent)
  end

  # `R-EDM-REQ-C092` is not applied to these names, where it is to the requesting
  # collection's: its context carries no ancestor, so it does reach them, and
  # `docs/reste_à_faire.md` records that partiality rather than this reader
  # silently standing for it.
  def require_provider_names(agent)
    agent_names(agent, :provider).each { |name| agent_language(name, :provider) }
  end
end
