# What chapter 4.6 asks of a received request at the `1.2.5` tag and no longer
# at the `2.0.1` one. Four rules it publishes there alone — `R-EDM-REQ-C004` on
# the localised string of the `Procedure` slot, `C069` on the request element
# itself, `C035` and `C072` on the `sdg:Transformation` a distribution may ask
# for — and one it publishes on both lines with the count turned round,
# `C032` on `sdg:DistributedAs`.
#
# What they have in common is the line and not the subject, and that is what
# makes them a family: a reader holding every request to the 2.0 rule set
# applies none of the four, and one holding every request to these refuses on
# `C032` exactly the messages the other admits. So each reading is guarded by
# the predicate of `EdmSpecification` that says which line shapes it, and none
# of them changes what a 2.0 message is judged by.
#
# `R-EDM-REQ-C092` is not here, though its context differs between the two tags
# too: it is one walk over the whole document, which is `WordingConformance`'s,
# and the line only chooses which table that walk filters by.
#
# Two entry points, because the refusals do not all fall at the same moment:
# `require_earlier_line_rules` is called among the checks of `validate!`, and
# `require_counted_distributions` at the read of the formats, which is the count
# it commands.
#
# Apart from the parser, as the six conformance modules beside it are, and for
# the reason `RequirementConformance` states: the class does not fit the rules
# of a seventh subject.
#
# Refusals go through `refuse`, which the parser including this defines.
module EarlierLineConformance
  include OotsNamespaces

  # No assertion of the 1.2.5 line refuses a request asking for no distribution
  # at all: `R-EDM-REQ-C032` counts `= 1 or = 0` there, and none satisfies it.
  # `DataServiceEvidenceTypeType` makes `sdg:DistributedAs` `minOccurs="1"` in
  # the 1.2.0 profile, and chapter 4.5.1 §3.5 asks for « one distribution
  # containing at least the Format » — so the floor is schema and prose, named
  # here as `AgentConformance::AGENT_IDENTIFIER_REQUIRED` names its own.
  DISTRIBUTION_REQUIRED = 'TDD 4.5.1 §3.5: at least one requested distribution'.freeze

  # `R-EDM-REQ-C035`, copied from the Schematron and not tightened — the
  # convention `RequirementConformance::REQUIREMENT_IDENTIFIER` states: `\A` for
  # `^`, and the points left unescaped where the assertion leaves them. The
  # alternation sits at the top level in the assertion, so `\A` binds the left
  # branch alone and a value carrying `distributions/` anywhere satisfies the
  # rule. It is wider than the prose of chapter 4.5.1 §3.5, which cites the
  # prefix with no environment infix: the assertion is what plays.
  TRANSFORMATION = %r{\Ahttps://sr(?:\.[a-zA-Z]+)?.oots.tech.ec.europa.eu/datamodels|distributions/}

  # Where `C035` and `C072` find their context nodes, written from `query:Query`
  # down: the distributions of the evidence type asked for are the only ones a
  # request carries.
  TRANSFORMATIONS =
    "./rim:Slot[@name='EvidenceRequest']/rim:SlotValue/sdg:DataServiceEvidenceType/sdg:DistributedAs/sdg:Transformation".freeze

  private

  # `R-EDM-REQ-C032` counts `sdg:DistributedAs` `> 0` at the 2.0.1 tag and
  # `= 1 or = 0` at the 1.2.5 one — « must occur not more than once », and the
  # 4.6 published at that tag says as much, `Role FATAL`. So the very request
  # the later line admits, a structured format with a human-readable fallback
  # beside it, is the one the earlier refuses; and what asks for the first
  # distribution there is the chapter alone.
  def require_counted_distributions(distributions)
    return require_single_distribution(distributions) if specification.single_distribution?
    return unless distributions.empty?

    refuse('R-EDM-REQ-C032', 'parsers.evidence_request.evidence_type_without_distribution')
  end

  # The 1.2 line, where one and only one is asked for: none is refused under the
  # chapter, which is what asks for a distribution, and more than one under the
  # rule, which is what forbids the second. One French sentence serves both
  # floors, being as true of one line as of the other.
  def require_single_distribution(distributions)
    if distributions.empty?
      refuse(DISTRIBUTION_REQUIRED, 'parsers.evidence_request.evidence_type_without_distribution')
    elsif !distributions.one?
      refuse('R-EDM-REQ-C032', 'parsers.evidence_request.evidence_type_with_several_distributions',
        count: distributions.size)
    end
  end

  def require_earlier_line_rules
    require_conformant_languages
    require_conformant_transformations
  end

  # The context of `C004` and of `C069` *is* the attribute, so neither ever asks
  # for it — an absent attribute opens no context — where one written empty is a
  # context node, and falls on the comparison. 2.0.1 publishes neither: the
  # procedure is a plain string there, and the language of a request moved into
  # each distribution.
  def require_conformant_languages
    if specification.translated_procedure?
      require_language_code(procedure_language, 'R-EDM-REQ-C004',
        'parsers.evidence_request.procedure_language_unknown')
    end
    return unless specification.request_language?

    require_language_code(attribute(request, 'lang', 'xml'), 'R-EDM-REQ-C069',
      'parsers.evidence_request.request_language_unknown')
  end

  # Compared exactly, both assertions carrying no `i` flag where the list
  # publishes upper case: `LanguageCode` holds the reason, and `C108` and `C009`
  # already compare that way.
  def require_language_code(language, rule, key)
    return if language.nil? || LanguageCode.valid?(language)

    refuse(rule, key, language:)
  end

  # The language of the localised string `EvidenceRequestParser#procedure_code`
  # reads the code from. Reached from the request rather than through `slot`,
  # which refuses an absent slot naming no rule: `R-EDM-REQ-S007` counts that
  # slot, and has already run.
  def procedure_language
    localised = at(request, "./rim:Slot[@name='Procedure']/rim:SlotValue/rim:Value/rim:LocalizedString")

    attribute(localised, 'lang', 'xml')
  end

  # `sdg:Transformation` names the subset of a conformance profile the
  # distribution is asked to follow, and the element belongs to
  # `EvidenceTypeDistributionType` in the 1.2.0 profile alone — a transformation
  # being a distribution of its own in 2.0. `R-EDM-REQ-C113` judges the same
  # context under `CAUTION`, and so refuses nothing, as `S014` does not.
  #
  # Among the checks of `validate!` and not at the read, where `C032` sits: that
  # count commands the reading of the formats, where these two judge a value
  # France never exploits — it is read to be judged and for nothing else.
  #
  # Walked from `query` and not through `slot_content`, which refuses a missing
  # evidence type naming no rule: a request carrying none is refused by the
  # readers that need it, and this one has nothing to say about it.
  def require_conformant_transformations
    return unless specification.transformable_distribution?

    all(query, TRANSFORMATIONS).each do |transformation|
      require_expected_transformation(transformation)
      require_transformed_conformance(transformation)
    end
  end

  # `squish` is `normalize-space`, which the assertion applies before matching.
  def require_expected_transformation(transformation)
    value = transformation.text.squish
    return if value.match?(TRANSFORMATION)

    refuse('R-EDM-REQ-C035', 'parsers.evidence_request.transformation_unexpected',
      transformation: value.presence || I18n.t('parsers.evidence_request.unnamed_transformation'))
  end

  # `R-EDM-REQ-C072`: `count(../sdg:ConformsTo) = 1`. A transformation names the
  # subset of a model, so without exactly one model beside it, it names the
  # subset of nothing.
  def require_transformed_conformance(transformation)
    return if all(transformation.parent, './sdg:ConformsTo').one?

    refuse('R-EDM-REQ-C072', 'parsers.evidence_request.transformation_without_conformance')
  end
end
