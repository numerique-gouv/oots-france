# What chapter 4.6 asks of the `EvidenceProviderClassification` slot of a
# received request: that each element of its collection carries a
# classification, and that each classification names itself, declares what it is
# typed as, carries the one value the user settled on, and describes itself in a
# language of the code list. Seventeen FATAL rules, every one of them fired
# below the slot.
#
# The slot itself is not required: `R-EDM-REQ-S014` counts it under `CAUTION`,
# where the rules counting the slots this parser does require are `FATAL`. It is
# read through `optional_slot_elements` for that reason, and stays out of
# `EvidenceRequestParser::REQUIRED_SLOTS`.
#
# Apart from the parser, as `AgentConformance` and `RequirementConformance` are,
# and for the reason the second states: the class does not fit the rules of a
# fifth slot. `AgentConformance` is included for `require_language` alone, which
# holds any element the chapter obliges to name its language: `C022` and `C021`
# over a description are, word for word, the pair of assertions it already reads
# for an agent's name and for a requirement's wordings.
#
# The readings are grouped by subject and not by identifier — the identifier,
# the type, the values, what the type `codelist` adds, the descriptions — since
# the chapter publishes several identifiers over one subject and, twice, one
# assertion under two of them.
#
# Refusals go through `refuse`, which the parser including this defines.
module ClassificationConformance
  include OotsNamespaces
  include AgentConformance

  # `R-EDM-REQ-C019`: a bare UUID, with neither the `urn:uuid:` prefix
  # `R-EDM-REQ-S004` puts on the request's own identifier nor any constraint on
  # the version nibble and the variant one. Case-insensitive, its assertion
  # carrying the `i` flag where `C008`'s does not.
  CLASSIFICATION_IDENTIFIER = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  # `R-EDM-REQ-C097`, copied from the Schematron dot for dot. Its assertion
  # escapes the point of the optional environment midfix and no other, so every
  # remaining `.` matches any character at all and
  # `https://sr-oots.tech.ec.europa.eu/codelists/DE/Lau2022` satisfies the rule
  # — the reading `RequirementConformance::REQUIREMENT_IDENTIFIER` gives `C008`,
  # and for the same reason: refusing what a FATAL rule admits is the failure
  # this reader exists to avoid.
  #
  # The country is upper case and the short name is either: the assertion
  # carries no `i` flag, and `matches()` without `m` reads `^` and `$` as the
  # ends of the string, which in Ruby are `\A` and `\z`.
  CLASSIFICATION_SCHEME = %r{\Ahttps://sr(?:\.[a-zA-Z]+)?.oots.tech.ec.europa.eu/codelists/[A-Z]{2}/[A-Za-z0-9]{2,50}\z}

  # `R-EDM-REQ-C099` on the last segment of that same `schemeID`, which it cuts
  # out with `tokenize(@schemeID, '/')[last()]` and matches **without**
  # normalising. What `C097` admits satisfies this too, save on one point: a
  # `schemeID` ending in a blank breaks this rule alone.
  SCHEME_SHORT_NAME = /\A[A-Za-z0-9]{2,50}\z/

  # `R-EDM-REQ-C095`, compared as its assertion compares — raw, with neither
  # `normalize-space` nor an `i` flag, so ` codelist ` and `Codelist` are
  # refused.
  TYPES = %w[string boolean codelist].freeze

  # The type whose three extra rules `require_code_list_expression` reads, and
  # the one the example published with chapter 4.5.1 carries.
  CODE_LIST = 'codelist'.freeze

  # The types `R-EDM-REQ-C103` holds to a `sdg:StringValue`, where `C104` holds
  # `boolean` to a `sdg:BooleanValue`.
  STRING_TYPES = %w[codelist string].freeze

  private

  # `R-EDM-REQ-S041` is what each element of the collection owes, and it is
  # refused here rather than passed over: its context is the `rim:Element`,
  # which exists — it came out of the collection — so the assertion does fire on
  # it. The same reading, and the same reason, as `R-EDM-REQ-S037` over the
  # `Requirements` slot.
  #
  # Every classification of every element, `InformationConceptType` naming no
  # upper bound the slot would have to respect.
  def require_conformant_classifications
    optional_slot_elements('EvidenceProviderClassification', request).each do |element|
      classifications = all(element, './sdg:EvidenceProviderClassification')
      refuse('R-EDM-REQ-S041', 'parsers.evidence_request.element_without_classification') if classifications.empty?

      classifications.each { |classification| require_conformant_classification(classification) }
    end
  end

  # By subject, and in this order because refusing on the first breach imposes
  # one and no rule of the chapter fixes it: what the classification is called,
  # what it is typed as, the value it carries, what the type `codelist` adds,
  # and how it describes itself.
  def require_conformant_classification(classification)
    require_classification_identifiers(classification)
    types = require_classification_type(classification)
    require_supported_values(classification, types)
    require_code_list_expression(classification) if types.include?(CODE_LIST)
    require_classification_descriptions(classification)
  end

  # `R-EDM-REQ-C019` on each identifier, then the three rules its `@schemeID`
  # carries. A classification naming no identifier breaks none of them, every
  # context here being the element or below it — the shape
  # `require_requirement_identifier` takes for the same reason.
  def require_classification_identifiers(classification)
    all(classification, './sdg:Identifier').each do |identifier|
      require_classification_uuid(identifier)
      require_classification_scheme(identifier)
    end
  end

  # `squish` is `normalize-space`, which the assertion applies before matching.
  def require_classification_uuid(identifier)
    id = identifier.text.squish
    return if id.match?(CLASSIFICATION_IDENTIFIER)

    refuse('R-EDM-REQ-C019', 'parsers.evidence_request.classification_id_not_a_uuid',
      id: id.presence || I18n.t('parsers.evidence_request.unnamed_classification_id'))
  end

  # The shape of the `schemeID`, then the country it names, then its last
  # segment: `C097` and `C098` have the attribute for context and say nothing of
  # an identifier carrying none, where `C099` narrows its own context to
  # `sdg:Identifier[@schemeID]` and reads the attribute raw.
  #
  # `C098` names the `schemeID` as received and not the segment read out of it:
  # that segment is empty in the cases that fail most often, and a sentence
  # naming nothing would leave the correspondent with nothing to look for.
  def require_classification_scheme(identifier)
    scheme = attribute(identifier, 'schemeID')
    return if scheme.nil?

    refuse('R-EDM-REQ-C097', 'parsers.evidence_request.classification_scheme_unexpected', scheme:) unless scheme.squish.match?(CLASSIFICATION_SCHEME)
    refuse('R-EDM-REQ-C098', 'parsers.evidence_request.classification_country_unknown', scheme:) unless IdentifierScheme.oots_country?(scheme)
    return if scheme.split('/').last.to_s.match?(SCHEME_SHORT_NAME)

    refuse('R-EDM-REQ-C099', 'parsers.evidence_request.classification_scheme_name_unexpected', scheme:)
  end

  # `R-EDM-REQ-C020` reads `normalize-space(sdg:Type)`, which turns a node-set
  # into the string of its first element, where `C095` compares with an `=`
  # that is existential over them all — and so do the `[sdg:Type='codelist']`
  # predicates of `C096`, `C100` and `C101`. Each is read as its assertion reads
  # it, and the types are handed back so the readings that follow judge the same
  # thing.
  def require_classification_type(classification)
    declared = all(classification, './sdg:Type')
    refuse('R-EDM-REQ-C020', 'parsers.evidence_request.classification_without_type') if declared.first&.text.to_s.squish.empty?

    types = declared.map(&:text)
    return types if types.intersect?(TYPES)

    refuse('R-EDM-REQ-C095', 'parsers.evidence_request.classification_type_unexpected', type: types.first)
  end

  # `R-EDM-REQ-C023` holds two things at once — at least one `sdg:SupportedValue`,
  # and none of them empty after `normalize-space` — and `C105` then asks for
  # exactly one, « along the answer chosen by the user ».
  #
  # `C102` is never named in a refusal: its assertion is word for word `C023`'s,
  # under a context restricted to the three published types, so what `C102`
  # refuses `C023` refuses already and never the other way round. A
  # classification typed outside the list is refused by `C095` above, where the
  # context of `C102` does not even open.
  def require_supported_values(classification, types)
    values = all(classification, './sdg:SupportedValue')
    refuse('R-EDM-REQ-C023', 'parsers.evidence_request.classification_without_supported_value') if values.empty?
    refuse('R-EDM-REQ-C023', 'parsers.evidence_request.classification_supported_value_empty') if values.any? { |value| value.text.squish.empty? }
    refuse('R-EDM-REQ-C105', 'parsers.evidence_request.classification_values_counted', count: values.size) unless values.one?

    require_value_element(values, 'StringValue', 'R-EDM-REQ-C103') if types.intersect?(STRING_TYPES)
    require_value_element(values, 'BooleanValue', 'R-EDM-REQ-C104') if types.include?('boolean')
  end

  # Every supported value, and not the first alone: the context of `C103` and
  # `C104` is the `sdg:SupportedValue` element, and both assert the presence of
  # a child and nothing of its content — a `sdg:StringValue` written blank
  # satisfies them, and is refused by `C092`, whose context reaches it.
  def require_value_element(values, name, rule)
    values.each do |value|
      next if at(value, "./sdg:#{name}")

      refuse(rule, "parsers.evidence_request.classification_value_without_#{name.underscore}")
    end
  end

  # What the type `codelist` adds, and it alone: `R-EDM-REQ-C096` on the
  # `schemeID` of the identifier, `C100` and `C101` on the value expression.
  #
  # `C096` reads `sdg:Identifier/@schemeID`, which is the first such attribute
  # in document order and not the first identifier's — an identifier carrying
  # none is passed over rather than counted as an empty one.
  #
  # `C101` matches on `sdg:ValueExpression/text()`, raw: `HTTPS://` satisfies
  # it, `lower-case` being applied first, and a single blank in front does not.
  # An expression that is not there breaks `C100` and `C101` alike, an empty
  # sequence starting with nothing.
  def require_code_list_expression(classification)
    scheme = all(classification, './sdg:Identifier').filter_map { |identifier| attribute(identifier, 'schemeID') }.first
    refuse('R-EDM-REQ-C096', 'parsers.evidence_request.classification_without_scheme') if scheme.to_s.empty?

    expression = text_at(classification, './sdg:ValueExpression')
    refuse('R-EDM-REQ-C100', 'parsers.evidence_request.classification_without_value_expression') if expression.to_s.squish.empty?
    return if expression.to_s.downcase.start_with?('https://')

    refuse('R-EDM-REQ-C101', 'parsers.evidence_request.classification_expression_not_https', expression:)
  end

  # `R-EDM-REQ-C022` and `C021` — the language of each description, absent or
  # blank under the first and outside the code list under the second. The very
  # pair `require_language` reads for an agent's name, and it is called rather
  # than copied: only the identifiers and the French sentence differ, and
  # `AgentConformance::RULES` is where both are said.
  #
  # Every `sdg:Description`, `InformationConceptType` making them `0..n` and the
  # contexts being the element and its attribute, each on its own.
  def require_classification_descriptions(classification)
    all(classification, './sdg:Description').each do |description|
      require_language(description, :classification_description)
    end
  end
end
