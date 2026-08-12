# The evidence types that satisfy a requirement, as the Evidence Broker
# returns them (chapter 3.2.4).
#
# The answer is already restricted to the jurisdiction asked for, and groups
# the types into `sdg:EvidenceTypeList`s: a list holds the types that together
# meet the requirement, and several lists are alternatives to one another.
# Flattening them is what `Directories::CommonServices` keeping the first type
# already does; telling the user which list to pick is chapter 4.10.
class EvidenceTypesResponseParser < CommonServicesResponseParser
  def evidence_types = @read

  private

  def read
    records(REQUIREMENT).flat_map do |declared|
      all(declared, './sdg:EvidenceTypeList/sdg:EvidenceType').map { |found| build(found) }
    end
  end

  # `StructuredEvidenceTypeDistribution` names the format only for a structured
  # evidence type; an unstructured one leaves `EvidenceType` to its default.
  #
  # Validated here and not left to the message builder: an entry without its
  # classification would otherwise travel as far as the `EvidenceTypeClassification`
  # slot of an outgoing request, which the TDD make mandatory, and go out empty.
  def build(found)
    format = text_at(found, './sdg:StructuredEvidenceTypeDistribution/sdg:Format')&.strip

    EvidenceType.new(
      id: text_at(found, './sdg:EvidenceTypeClassification')&.strip,
      descriptions: by_language(all(found, './sdg:Title')),
      **(format.present? ? { distribution_format: format } : {}),
    ).validate!("Le type de justificatif annoncé par l'annuaire", error: CommonServicesError)
  end
end
