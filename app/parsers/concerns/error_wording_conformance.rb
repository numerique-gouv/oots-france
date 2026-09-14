# The two rules chapter 4.6 applies to the wordings of a received error report
# wherever they sit: `R-EDM-ERR-C027`, which holds every one of them to two
# characters, and `-S030`, which forbids two of one language side by side.
#
# Two rules, two walks, and that is the family: neither has an ancestor in its
# context, so neither can be hung off the reader of any one element — where
# every other module here judges a subtree it can name. They are the net under
# everywhere those readers do not go, and they reach a document that is no
# `query:QueryResponse` at all, which nothing else here does.
#
# Read and never refused, like every rule this parser confronts a report to:
# `ErrorResponseParser#violations` says why.
#
# Apart from the parser, as the four conformance modules beside it are, and for
# the reason `ErrorEnvelopeConformance` states.
#
# `document`, `specification`, `violation` and `named` are the includer's.
module ErrorWordingConformance
  include OotsNamespaces

  # The twenty-one names the 2.0.1 context lists, verbatim and in its order,
  # each under the length the test asks of it: `$text_length > 1` for twenty of
  # them, and `> 0` for the one the disjunction names besides. One table and not
  # a list plus its exceptions — a name in the second and not in the first would
  # be dead without anything saying so.
  #
  # Written out rather than derived from `WordingConformance::MINIMUM_LENGTHS`,
  # which holds the same names for `R-EDM-REQ-C092` on the request: that rule
  # exempts `sdg:StringValue` as well as the locator, and this one exempts the
  # locator alone. The convention `EvidenceResponseParser::REQUEST_IDENTIFIER`
  # states — what the two rules have in common is the wording of the TDD, not a
  # decision this repository takes once.
  MINIMUM_LENGTHS = {
    'Description' => 2, 'Name' => 2, 'Title' => 2, 'Note' => 2, 'EvidenceTypeClassification' => 2,
    'FullAddress' => 2, 'LocatorDesignator' => 1, 'PostCode' => 2, 'PostCityName' => 2, 'Thoroughfare' => 2,
    'PlaceOfBirth' => 2, 'TownOfBirth' => 2, 'PhoneNumber' => 2, 'EmailAddress' => 2, 'LegalPhoneNumber' => 2,
    'LegalEmailAddress' => 2, 'nonLatin' => 2, 'ValueExpression' => 2, 'StringValue' => 2, 'AttributeName' => 2,
    'AttributeValue' => 2,
  }.freeze

  # What the 1.2.5 context adds to that list: the two wordings of the
  # jurisdiction determination, `JurisditionLevel` spelled as the rule spells it
  # and not as the 1.2.0 schema does. `WordingConformance::EARLIER_LINE_MINIMUM_LENGTHS`
  # carries the same two rows for the request, and says at length why a rule
  # that reaches no element of a schema-valid document is transcribed all the
  # same.
  EARLIER_LINE_MINIMUM_LENGTHS = MINIMUM_LENGTHS
    .merge('JurisdictionContext' => 2, 'JurisditionLevel' => 2)
    .freeze

  private

  def wording_violations
    [*wordings_too_short, *wordings_sharing_a_language]
  end

  # Every `sdg:*` element of the report, filtered by the table: walking the
  # document once is what the rule's context does, where twenty-one XPath
  # expressions would only say the same thing at greater length.
  #
  # `squish` is `normalize-space`, which the assertion applies before measuring:
  # ` A ` is one character to the rule, and so is a name split over two lines.
  def wordings_too_short
    minimums = wording_minimum_lengths

    all(document, '//sdg:*').filter_map do |wording|
      minimum = minimums[wording.name]
      next if minimum.nil?

      value = wording.text.squish
      next if value.length >= minimum

      violation('R-EDM-ERR-C027', wording_key(minimum), path: wording.path, value: named(value, 'absent_value'))
    end
  end

  # `-S030`, whose context is `*[@lang]` — every element of the document
  # carrying that attribute, of whatever namespace — and whose test counts the
  # siblings sharing its local name and its language, asking for exactly one. So
  # it reaches the names of either agent and anything else a correspondent
  # writes in two languages.
  #
  # `@lang` and never `xml:lang`: the assertion names the attribute without a
  # namespace, so the `rim:LocalizedString` of a `PreviewDescription` — which
  # carries `xml:lang`, and which `C020` is what judges — is not in its context.
  #
  # `local-name()` on both sides and no comparison of namespaces, as published:
  # an `sdg:Name` and an `x:Name` of one language are two elements of the same
  # local name to this rule, and it refuses them.
  #
  # Grouped rather than counted node by node, which is the same reading done
  # once: the assertion asks that no group of (parent, local name, language)
  # hold more than one element.
  def wordings_sharing_a_language
    all(document, '//*[@lang]').group_by { |worded| [worded.parent.path, worded.name, attribute(worded, 'lang')] }
      .filter_map do |(_parent, name, language), worded|
        next if worded.one?

        violation('R-EDM-ERR-S030', 'wordings_share_a_language',
          name:, language: named(language, 'unnamed_language'), count: worded.size)
      end
  end

  # The list of the line the report is read in, as
  # `ErrorRegRepShapeConformance#slot_types` reads the table of its own.
  def wording_minimum_lengths
    specification.jurisdiction_determination? ? EARLIER_LINE_MINIMUM_LENGTHS : MINIMUM_LENGTHS
  end

  # Two sentences rather than one carrying a number: shorter than one character
  # is empty, and saying so is clearer than naming a length of one.
  def wording_key(minimum)
    return 'wording_empty' if minimum == 1

    'wording_too_short'
  end
end
