# What chapter 4.6 asks of an `sdg:Agent` of a received request: its identifier,
# the scheme that identifier names, its names and the language of each. None of
# these rules narrows its context to a classification — `R-EDM-REQ-C073`, which
# does, is therefore not here — so the same reading serves the agent classified
# `ER`, the ones beside it, and the provider the request designates.
#
# Two readers here judge no agent. `require_language` holds any element the
# chapter obliges to name its language: four pairs of rules make that one pair
# of assertions — over the requester's collection, over the provider, and over
# the name and the description of a requirement — so it is written once and
# reads its identifiers from `RULES`, like the agent readers beside it.
# `refuse_unexpected_children` holds any element whose children the chapter
# closes to a list of names, which `R-EDM-REQ-S043` does over the provider and
# `S038` over a requirement. Both are here because `RequirementConformance`
# includes this module for exactly that, and says so.
#
# Each reading takes a `wording` naming the agent it judges, which it cannot
# know itself: one rule refuses the requester, the platform beside it and the
# provider in three different French sentences, and `RULES` says under which
# identifier that rule is published for each. `require_conformant_agent` walks
# the agents the requester is not, which is where `C013` and `C014` are applied
# — those two alone, the classification of the agent retained as requester being
# `ER` by construction. The requester reads its own identifier through
# `require_agent_identifier` all the same, from
# `EvidenceRequestParser#build_requester`, which refuses without answering for
# what an error response would copy back.
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

  # What `R-EDM-REQ-S043` admits under the agent of the `EvidenceProvider` slot,
  # and nothing else — no address, no classification.
  PROVIDER_CHILDREN = %w[Identifier Name].freeze

  # What the readers below refuse, under the identifier each rule is published
  # by for the agent being judged. The slot fixes that identifier and never the
  # classification: `C011`, `C012`, `C109` and `C108` judge every agent of the
  # `EvidenceRequester` collection, and `C017`, `C018`, `C111` and `C110` are
  # those four assertions again, written word for word the same over the
  # provider's slot.
  REQUESTER_COLLECTION_RULES = {
    identifier: 'R-EDM-REQ-C012', language: 'R-EDM-REQ-C109', language_code: 'R-EDM-REQ-C108',
    identifier_required: AGENT_IDENTIFIER_REQUIRED, scheme: 'R-EDM-REQ-C011',
    name_required: AGENT_NAME_REQUIRED,
  }.freeze

  # The requester and the platform beside it break the same rules under the same
  # identifiers, the slot fixing those and never the classification: the two
  # rows differ by the French sentence their key names, and by nothing else.
  RULES = {
    agent: REQUESTER_COLLECTION_RULES,
    platform: REQUESTER_COLLECTION_RULES,
    provider: {
      identifier: 'R-EDM-REQ-C018', language: 'R-EDM-REQ-C111', language_code: 'R-EDM-REQ-C110',
      identifier_required: PROVIDER_IDENTIFIER_REQUIRED, scheme: 'R-EDM-REQ-C017',
      name_required: PROVIDER_NAME_REQUIRED,
    }.freeze,
    # The agents of the same slot the request does not designate. The four
    # rules are the provider's own — no context of theirs carries a positional
    # predicate, so each agent of the slot value breaks them alike — and only
    # the French sentence differs: a second agent is not « le fournisseur
    # désigné », and a refusal saying it were would name the wrong one.
    accompanying_provider: {
      identifier: 'R-EDM-REQ-C018', language: 'R-EDM-REQ-C111', language_code: 'R-EDM-REQ-C110',
      scheme: 'R-EDM-REQ-C017',
    }.freeze,
    # These two judge no agent at all: `C010`/`C009` and `C094`/`C093` hold the
    # name and the description of a `Requirements` exigence to naming their
    # language, which is that same pair of assertions a third and a fourth
    # time. They are here because the reader is, and splitting the table would
    # split it by subject rather than by what it does.
    requirement_name: { language: 'R-EDM-REQ-C010', language_code: 'R-EDM-REQ-C009' }.freeze,
    requirement_description: { language: 'R-EDM-REQ-C094', language_code: 'R-EDM-REQ-C093' }.freeze,
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
    return name.text if name.text.squish.length > 1

    refuse('R-EDM-REQ-C092', "parsers.evidence_request.#{wording}_name_too_short", name: name.text)
  end

  # `R-EDM-REQ-C109`, `C111` on the provider, asserts `not(normalize-space(@lang)='')`,
  # so an attribute absent and one written blank break it alike. `R-EDM-REQ-C108`,
  # `C110` on the provider, then compares the raw value to the code list,
  # `.=$code` carrying no `i` flag and the list publishing upper case:
  # `lang="fr"` breaks it where `lang="FR"` does not, and so does ` FR `, which
  # the first rule accepts.
  # Named for what it reads and not for who carries it: four pairs of rules make
  # this one pair of assertions, and two of them judge a requirement's wordings,
  # which are not agents.
  def require_language(node, wording)
    rules = RULES.fetch(wording)
    language = attribute(node, 'lang')
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
    require_agent_names(agent, :platform)
    require_agent_country(agent)
    require_agent_territory(agent, :platform)
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
  #
  # Hands back the element it judged, which `EvidenceRequestParser#build_requester`
  # then reads the scheme and the identifier off: whoever needs the value needs
  # it vetted, and looking it up a second time would let the two come apart.
  def require_agent_identifier(agent, wording)
    identifier = at(agent, './sdg:Identifier')
    refuse(RULES.fetch(wording).fetch(:identifier_required), "parsers.evidence_request.#{wording}_without_identifier") if identifier.nil?

    require_identifier_scheme(identifier, wording)

    identifier
  end

  # The two rules an identifier that is there breaks on its own, apart from the
  # chapter that requires it to be there at all: an agent the request does not
  # designate owes nothing of its presence — no assertion says so — and owes
  # these two the moment it carries one.
  def require_identifier_scheme(identifier, wording)
    scheme = attribute(identifier, 'schemeID')
    refuse(RULES.fetch(wording).fetch(:scheme), "parsers.evidence_request.#{wording}_without_scheme") if scheme.nil?

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

  # Every rule the names of an agent are held to, whichever agent it is: one
  # method rather than one per slot, the sentences being what the `wording`
  # carries. Hands back the names it vetted, so that
  # `EvidenceRequestParser#build_requester` reads the first of them without
  # having to look it up again.
  def require_agent_names(agent, wording)
    agent_names(agent, wording).each do |name|
      agent_name(name, wording)
      require_language(name, wording)
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

  # `R-EDM-REQ-C016`, which holds an `sdg:AdminUnitLevel2` to the `NUTS` list as
  # `C015` holds the `AdminUnitLevel1` above it to the countries. Every element
  # is judged and none is required: the rule's context is the element itself, so
  # an agent naming no territory breaks nothing — `C073` requires the address
  # and nothing requires this.
  #
  # Compared raw, the assertion carrying neither `i` flag nor `normalize-space`,
  # where `C015`'s does the same: `FR101` satisfies it and `fr101` does not.
  #
  # Applied to the `EvidenceRequester` collection alone, which is the rule's
  # context: the provider's slot has no counterpart, so
  # `require_conformant_provider` does not call this.
  def require_agent_territory(agent, wording)
    all(agent, './sdg:Address/sdg:AdminUnitLevel2').each do |declared|
      territory = declared.text
      next if NutsCode.valid?(territory)

      refuse('R-EDM-REQ-C016', "parsers.evidence_request.#{wording}_territory_unknown", territory:)
    end
  end

  # What the agent of the `EvidenceProvider` slot owes, and all of it: no
  # classification, chapter 4.5.1 §3.3 asking for none, and no address, which is
  # `R-EDM-REQ-C073`'s to require of the agent classified `ER` alone.
  #
  # Takes the whole collection the slot value carries, and judges every agent of
  # it. `R-EDM-REQ-S043` asserts `count(sdg:Identifier) + count(sdg:Name) = count(child::*)`
  # of each — its context is every one of them, and it counts none — so the
  # closed list is applied to all. What chapter 4.5.1 §3.3 requires to be there
  # at all, an identifier and a name, is required of the one the request
  # designates, which is the first: the subsection describes that agent, and no
  # assertion says anything of a second one's absences.
  #
  # `C017`, `C018`, `C110` and `C111` are not restricted to that one either:
  # their contexts are `…/rim:SlotValue/sdg:Agent/sdg:Identifier` and
  # `…/sdg:Name`, with no positional predicate, so they reach a second agent as
  # much as the first — under their own sentences, a second agent not being the
  # one the request designates.
  def require_conformant_provider(agents)
    designated, *accompanying = agents
    require_agent_identifier(designated, :provider)
    require_agent_names(designated, :provider)
    accompanying.each { |declared| require_accompanying_provider(declared) }

    agents.each do |declared|
      refuse_unexpected_children(declared, PROVIDER_CHILDREN, 'R-EDM-REQ-S043',
        'parsers.evidence_request.provider_unexpected_children')
    end
  end

  # The agents of the slot the request does not designate: what they carry is
  # judged, and nothing is required of them. Neither an assertion nor chapter
  # 4.5.1 §3.3 says anything of a second agent's absent identifier or absent
  # name — the subsection describes the agent the slot designates — so this
  # reads each identifier and each name that is there, and no more.
  #
  # `R-EDM-REQ-C092` is deliberately not applied here: the walk of
  # `WordingConformance` reaches every `sdg:Name` of the document under that
  # same identifier, and applying it from here would hand the refusal the
  # sentence of the designated provider, which would name the wrong agent.
  def require_accompanying_provider(agent)
    all(agent, './sdg:Identifier').each { |identifier| require_identifier_scheme(identifier, :accompanying_provider) }
    all(agent, './sdg:Name').each { |name| require_language(name, :accompanying_provider) }
  end

  # What the rules asserting `count(sdg:A) + count(sdg:B) = count(child::*)`
  # refuse: an element the closed list does not name. They leave the count of
  # each admitted element free — two names satisfy such a rule — and they admit
  # nothing of another namespace, which the URI decides and never the prefix.
  #
  # `elements` counts what `child::*` counts, comments and text nodes excluded.
  def refuse_unexpected_children(node, admitted, rule, key)
    unexpected = node.elements.reject { |child| child.namespace&.href == NAMESPACES.fetch('sdg') && admitted.include?(child.name) }
    return if unexpected.empty?

    refuse(rule, key, children: unexpected.map(&:name).uniq.join(', '))
  end
end
