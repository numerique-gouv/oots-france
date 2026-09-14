# What chapter 4.6 asks of the values a received request hands to the response
# France signs: the classification of the evidence type asked for, the titles
# that describe it, and the eIDAS identifier of the evidence subject.
#
# The family is the principle and not the slot — the three sit under three
# different ones. Every value `app/templates/evidence_response.v2_0.xml.erb`
# copies out of a request is judged here, at the read, by the request rule that
# judges it; and where the Schematron publishes none, by the cardinality the
# chapter and the schema give it. The reason is that each of them is judged
# again in the response by a FATAL rule whose twin judges the request —
# `R-EDM-RESP-C017` for the classification, `C018` for the language of a title,
# `C028` and `C035` for the identifier — so a request that breaks one and is
# answered has France sign a message that breaks the other.
#
# `R-EDM-RESP-C019` is the twin deliberately not in that list, though it is
# FATAL on the same `sdg:Title`: it asserts only that `@lang` is *there*, and
# `evidence_response.v2_0.xml.erb` writes the attribute unconditionally, so it
# holds whatever the request carried — an empty `lang` satisfies it and falls
# to `C018`. `R-EDM-REQ-C029`, whose assertion is `not(normalize-space(@lang)
# ='')`, is therefore guarded here by `C018` alone. Refusing at the
# read is what `OOTS-190` settled for the requesting agent: nothing is added or
# filtered when the response is written, and an accepted request yields a
# conformant response by construction.
#
# `R-EDM-REQ-C041` and `C042` are here too, though the scheme they judge is not
# echoed — the response templates write `eidas` themselves. They belong with
# `C040` because that rule narrows its own context to `sdg:Identifier[@schemeID
# ='eidas']`: the scheme is what decides which rule judges the value, so the
# four read as one chain over one element, and splitting them between a class
# and a module would make a reader hunt for half of it.
#
# `R-EDM-REQ-C032` is not here, though the response does read the distributions:
# it is refused where the formats are read and not among the checks of
# `validate!`, and what the response announces is the format France served, not
# the one asked for — `EvidenceResponseBuilder#served_format`.
#
# Apart from the parser, as the six conformance modules beside it are, and for
# the reason `RequirementConformance` states: the class does not fit the rules
# of an eighth subject. `AgentConformance` is included for `require_language`
# alone, which holds any element the chapter obliges to name its language:
# `C029` and `C028` over a title are, word for word, the pair of assertions it
# already reads for an agent's name, a requirement's wordings and a provider
# classification's description.
#
# Refusals go through `refuse`, which the parser including this defines.
module EchoedValueConformance
  include OotsNamespaces
  include AgentConformance

  # The chapter alone, no assertion counting the titles of an evidence type:
  # `R-EDM-REQ-C029` and `C028` have `sdg:Title` and its `lang` in their
  # contexts, so a type carrying none breaks neither. The floor is the table of
  # chapter 4.5.1 §3.5, which gives `Title` `1..n` — « Unbounded cardinality to
  # support multiple languages » — and the XSD, where
  # `DataServiceEvidenceTypeType` makes it `minOccurs="1"`. Named here as
  # `AgentConformance::AGENT_NAME_REQUIRED` names its own.
  #
  # Chapter 4.5.2 §3.3 says the opposite of its own table, describing
  # `sdg:IsConformantTo` as carrying « optional Title and Description » where
  # that table gives `Title` `1..n` and `EvidenceTypeType` makes it
  # `minOccurs="1"`. The table and the schema are what play — the table is the
  # syntactic specification, the prose its summary — and `docs/carte_des_tdd.md`
  # records the disagreement. What that prose may be reaching for is the one
  # thing genuinely optional here: the `IsConformantTo` element itself, `0..1`
  # and `minOccurs="0"`. The container, never the title it carries.
  EVIDENCE_TYPE_TITLE_REQUIRED = 'TDD 4.5.1 §3.5: DataServiceEvidenceType title required'.freeze

  # `R-EDM-REQ-C027`, copied from the Schematron and not tightened — the
  # convention `RequirementConformance::REQUIREMENT_IDENTIFIER` states: the
  # points the assertion leaves unescaped stay unescaped, so
  # `https://sr-oots.tech.ec.europa.eu/…` satisfies the rule here as it does
  # there. Refusing what a FATAL rule admits is the failure this reader exists
  # to avoid.
  #
  # The country segment is the `OOTS_Country` code list plus the literal `oots`
  # the alternation adds « for testing purposes and agreed OOTS data models » —
  # exactly what `IdentifierScheme::UNREGISTERED_CODES` holds.
  #
  # Lower-case hexadecimal and no `i` flag anywhere, `C008`'s reading again; and
  # anchored at both ends, `matches()` without `m` reading `^` and `$` as the
  # ends of the string, which in Ruby are `\A` and `\z`.
  # `.source` and not the `Regexp` itself: interpolating a `Regexp` wraps it in
  # `(?-mix:…)`, which re-asserts its own flags and so defeats any the outer
  # expression carries — the trap `EIDAS_IDENTIFIER` falls into visibly, being
  # the one of the two that is case-insensitive.
  EVIDENCE_TYPE_CLASSIFICATION = %r{\Ahttps://sr(?:\.[a-zA-Z]+)?.oots.tech.ec.europa.eu/evidencetypeclassifications/
                                    (?:#{Regexp.union(IdentifierScheme::UNREGISTERED_CODES).source})/
                                    [a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\z}x

  # `R-EDM-REQ-C040` and `C051`, one assertion published twice, transcribed
  # whole rather than taken apart into two country segments: the doctrine this
  # repository follows for `C008` and `C097`. It carries no `^` and does carry a
  # `$`, so anything may precede the identifier and nothing may follow it —
  # `EidasIdentified` keeps the `\A` its own comment justifies, and this reading
  # does not, being the rule itself.
  #
  # The `i` flag is the assertion's: `es/at/02635542Y` is conformant, and
  # `R-EDM-RESP-C028` and `C035` carry the flag too, so echoing it back keeps
  # the answer conformant.
  EIDAS_IDENTIFIER = %r{(?:(?:#{Regexp.union(IdentifierScheme::OOTS_COUNTRIES).source})/){2}\S{6,256}\z}i

  # `R-EDM-REQ-C042` admits this value and no other. Its message adds that
  # `eidas2` « can be used for testing purposes until confirmation of provision
  # of a suitable legal basis », which its assertion does not: the assertion is
  # what plays.
  BENEFICIARY_SCHEME = 'eidas'.freeze

  # Where the rules find their context nodes, written from `query:Query` down.
  EVIDENCE_TYPES = "./rim:Slot[@name='EvidenceRequest']/rim:SlotValue/sdg:DataServiceEvidenceType".freeze

  # The two subjects an evidence request may name, keyed by their slot as
  # `SlotTypeConformance::QUERY_REQUEST_SLOT_TYPES` keys its own rows, each
  # carrying where the rule finds its context nodes and which rule that is.
  #
  # `R-EDM-REQ-C040` narrows itself to the eIDAS scheme, where `C051` judges
  # every `sdg:LegalPersonIdentifier` there is. The 1.2 line drops that
  # predicate from `C040`, to no effect: `C041` and `C042` are identical on both
  # lines and `require_beneficiary_identifier_scheme` has already refused any
  # other scheme, so every identifier reaching here carries this one.
  SUBJECT_IDENTIFIERS = {
    'NaturalPerson' => {
      path: "./rim:Slot[@name='NaturalPerson']/rim:SlotValue/sdg:Person/sdg:Identifier[@schemeID='eidas']",
      rule: 'R-EDM-REQ-C040',
    }.freeze,
    'LegalPerson' => {
      path: "./rim:Slot[@name='LegalPerson']/rim:SlotValue/sdg:LegalPerson/sdg:LegalPersonIdentifier",
      rule: 'R-EDM-REQ-C051',
    }.freeze,
  }.freeze

  private

  # One entry point among the checks of `validate!`, and the scheme first of the
  # three: that refusal names `C041` or `C042`, more precise than what follows,
  # and running it first is what honours the `[@schemeID='eidas']` of `C040`'s
  # context — every identifier reaching the next reader carries that scheme or
  # has already been refused.
  #
  # No rule of the chapter fixes this order, nor where the three sit among the
  # checks of `validate!`.
  def require_conformant_echoed_values
    require_beneficiary_identifier_scheme
    require_conformant_subject_identifiers
    require_conformant_evidence_types
  end

  # `R-EDM-REQ-C041` and `C042`, whose context is the identifier of the person a
  # `NaturalPerson` slot names: they fire on the element and not on the slot, so
  # a request carrying no identifier at all breaks neither — chapter 2.1
  # §2.3.1.2 provides for an identity established in the requester's own
  # country. The organisation's identifiers are `C054` and `C055`, applied by
  # `EvidenceRequestParser#legal_identifiers` and by `LegalPerson`.
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

  # Walked from `query` rather than through `slot_content`, for the reason
  # `EarlierLineConformance#require_conformant_transformations` gives of the
  # same subtree: a request carrying no evidence type is refused by the readers
  # that need one — `evidence_type`, under the chapter — and these rules, whose
  # contexts are the elements themselves, have nothing to say about it.
  #
  # Every type the slot carries is judged, no rule counting them.
  def require_conformant_evidence_types
    all(query, EVIDENCE_TYPES).each do |described|
      require_expected_classification(described)
      require_conformant_titles(all(described, './sdg:Title'))
    end
  end

  # The floor first and each title after it, the two never meeting: where there
  # is no title the rules have no context to fire on, and where there is one the
  # chapter is satisfied. Every title is judged and not the first alone — the
  # contexts are the element and its attribute, and the schema admits `1..n`, a
  # second language being the very reason it does.
  #
  # `R-EDM-REQ-C029` refuses an attribute absent or blank, its assertion being
  # `not(normalize-space(@lang)='')`, and `C028` a code the list does not
  # publish, compared exactly: that is `require_language`, word for word, which
  # is why this reader owns no comparison of its own.
  def require_conformant_titles(titles)
    refuse(EVIDENCE_TYPE_TITLE_REQUIRED, 'parsers.evidence_request.evidence_type_without_title') if titles.empty?

    titles.each { |title| require_language(title, :evidence_type_title) }
  end

  # Each classification that is there, and silence on a type carrying none: the
  # context of `R-EDM-REQ-C027` is the element itself, so its absence triggers
  # no assertion — the shape `require_requirement_identifier` takes for the same
  # reason, and `evidence_type` is what refuses the absence, under the chapter.
  #
  # Raw, where `C008` is read through `squish`: this assertion applies no
  # `normalize-space` before matching, so a value padded with blanks breaks it
  # and is refused rather than trimmed into conformance.
  #
  # `R-EDM-REQ-C115` judges the same element under `CAUTION` — the same
  # expression without the environment midfix — and so refuses nothing, as
  # `S014` does not: an acceptance URL is served.
  def require_expected_classification(described)
    all(described, './sdg:EvidenceTypeClassification').each do |classification|
      next if classification.text.match?(EVIDENCE_TYPE_CLASSIFICATION)

      refuse('R-EDM-REQ-C027', 'parsers.evidence_request.evidence_type_classification_unexpected',
        classification: classification.text.presence || I18n.t('parsers.evidence_request.unnamed_classification'))
    end
  end

  # Every identifier of both subjects, and silence on a subject carrying none:
  # the contexts are the elements, so a request naming a person with no
  # identifier at all breaks neither rule — chapter 2.1 §2.3.1.2 provides for an
  # identity established in the requester's own country. A request carrying both
  # slots is refused by `R-EDM-REQ-S016` before this, and both are walked all
  # the same, the rules counting nothing.
  #
  # The value is read raw: the assertion normalises nothing, and its missing `^`
  # is what admits a leading blank — `EvidenceRequestParser` trims that one at
  # the read, for the identifier it hands the response, and not here, where the
  # rule is what speaks.
  def require_conformant_subject_identifiers
    SUBJECT_IDENTIFIERS.each_value do |judged|
      all(query, judged.fetch(:path)).each do |identifier|
        next if identifier.text.match?(EIDAS_IDENTIFIER)

        refuse(judged.fetch(:rule), 'parsers.evidence_request.subject_identifier_country_unknown',
          identifier: identifier.text.presence || I18n.t('parsers.evidence_request.unnamed_subject_identifier'))
      end
    end
  end
end
