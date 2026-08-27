# The evidence types that satisfy a requirement, as the Evidence Broker
# returns them (chapter 3.2.4).
#
# The answer groups the types into `sdg:EvidenceTypeList`s: a list holds the
# types that together meet the requirement, and several lists are alternatives
# to one another. Flattening them is what `EvidenceRequest::ResolveEvidenceType`
# keeping the first type already does, and the console at least shows the
# grouping.
#
# `country-code` being optional on this query, the lists of every country come
# back at once — each naming its own jurisdiction.
class EvidenceTypesResponseParser < CommonServicesResponseParser
  def evidence_types = @read

  def evidence_type_lists = @lists

  private

  # The flattened types are what `@read` holds, so that an answer whose lists
  # are all empty is still rejected as unreadable — unless one of them says its
  # emptiness is deliberate.
  def read
    @lists = records(REQUIREMENT).flat_map do |declared|
      all(declared, './sdg:EvidenceTypeList').map { |found| build_list(found) }
    end

    @lists.flat_map(&:evidence_types)
  end

  # An explicitly empty list is a reading, not a failure to read. Chapter 3.2.4
  # has a member state declare `NoMatch` to say it knows no evidence of its own
  # satisfies the requirement in that jurisdiction, where `EB:ERR:0001` means
  # the broker holds no information at all — « the Evidence Broker does not
  # construct NoMatch automatically ».
  def nothing_readable? = super && !declared_empty?

  # `R-EB-EVI-S015` bears on one list — it excuses a list without evidence types
  # only under `NoMatch` — so **every** empty list has to say so for the answer
  # to count as read. One that stays silent is an answer we failed to read even
  # beside a neighbour that declared itself, and `country-code` being optional
  # here, that neighbour is often another member state entirely.
  def declared_empty? = @lists.any? && @lists.all?(&:no_match?)

  def build_list(found)
    EvidenceTypeList.new(
      id: text(found, './sdg:Identifier'),
      country: text(found, './sdg:Jurisdiction/sdg:AdminUnitLevel1').presence,
      descriptions: by_language(all(found, './sdg:Name')),
      match_type: text(found, './sdg:MatchType').presence,
      match_descriptions: by_language(all(found, './sdg:MatchDescription')),
      evidence_types: all(found, './sdg:EvidenceType').map { |type| build(type) },
    )
  end

  # `StructuredEvidenceTypeDistribution` names the format only for a structured
  # evidence type; an unstructured one leaves `EvidenceType` to its default.
  #
  # Validated here and not left to the message builder: an entry without its
  # classification would otherwise travel as far as the `EvidenceTypeClassification`
  # slot of an outgoing request, which the TDD make mandatory, and go out empty.
  def build(found)
    format = text(found, './sdg:StructuredEvidenceTypeDistribution/sdg:Format')

    EvidenceType.new(
      id: text(found, './sdg:EvidenceTypeClassification'),
      descriptions: by_language(all(found, './sdg:Title')),
      details: by_language(all(found, './sdg:Description')),
      **(format.present? ? { distribution_format: format } : {}),
    ).validate!(:announced_evidence_type, error: CommonServicesError)
  end
end
