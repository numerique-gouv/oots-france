# What chapter 4.6 asks of the `EvidenceProviderClassification` slot of a
# received request: that each element of its collection carries a
# classification, that each identifier names a country taking part in OOTS, and
# that each description names a language of the code list.
#
# The slot itself is not required: `R-EDM-REQ-S014` counts it under `CAUTION`,
# where the rules counting the slots this parser does require are `FATAL`. It is
# read through `optional_slot_elements` for that reason, and stays out of
# `EvidenceRequestParser::REQUIRED_SLOTS`.
#
# Apart from the parser, as `AgentConformance` and `RequirementConformance` are,
# and for the reason the second states: the class does not fit the rules of a
# fifth slot.
#
# Refusals go through `refuse`, which the parser including this defines.
module ClassificationConformance
  include OotsNamespaces

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

      classifications.each do |classification|
        require_classification_country(classification)
        require_classification_languages(classification)
      end
    end
  end

  # `R-EDM-REQ-C098`, whose context is the `@schemeID` attribute: an identifier
  # carrying none breaks nothing, and one written empty breaks the rule, its
  # country segment being empty too.
  #
  # The refusal names the `schemeID` as received and not the segment read out of
  # it: that segment is empty in the cases that fail most often, and a sentence
  # naming nothing would leave the correspondent with nothing to look for.
  def require_classification_country(classification)
    all(classification, './sdg:Identifier').each do |identifier|
      scheme = attribute(identifier, 'schemeID')
      next if scheme.nil? || IdentifierScheme.oots_country?(scheme)

      refuse('R-EDM-REQ-C098', 'parsers.evidence_request.classification_country_unknown', scheme:)
    end
  end

  # `R-EDM-REQ-C021` alone, and `C022` deliberately not: the second asserts
  # `not(normalize-space(@lang)='')` on the `sdg:Description` element, and this
  # reader leaves it to whoever applies the twelve other rules of the slot. So a
  # description naming no language at all is served — `C021`'s context is the
  # attribute, which is then not there — where one written empty is refused,
  # the empty string being no code of the list.
  #
  # `require_language` of `AgentConformance` is not reused for exactly that: it
  # refuses an absent attribute under its own rule's twin, which would apply
  # `C022` here without saying so.
  #
  # Every `sdg:Description`, `InformationConceptType` making them `0..n` and the
  # rule's context being each attribute on its own.
  def require_classification_languages(classification)
    all(classification, './sdg:Description').each do |description|
      language = attribute(description, 'lang')
      next if language.nil? || LanguageCode.valid?(language)

      refuse('R-EDM-REQ-C021', 'parsers.evidence_request.classification_language_unknown', language:)
    end
  end
end
