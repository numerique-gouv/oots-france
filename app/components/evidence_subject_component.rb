# The evidence subject of a journal event, read back field by field instead of
# as the JSON string the column holds.
#
# Chapter 4.5.1 lets that subject be exactly one of two slots — a `NaturalPerson`
# or a `LegalPerson` — and gives each of them attributes no single field holds: a
# person carries its nationalities (`0..n`) and a structured `CurrentAddress`, an
# organisation its alternative identifiers (`0..n`) and a `RegisteredAddress`. So
# the rendering walks the value instead of listing the fields written today, and
# a field either subject gains shows up without this component being reopened.
#
# A name no wording translates is shown as it is. That is what keeps such a field
# legible before anyone has named it, and it is also how the identifier schemes
# read: `VAT`, `LEI` and `EORI` are the values `R-EDM-REQ-C055` compares to
# `IdentifierSchemes` word for word, and a journal shows what circulated.
class EvidenceSubjectComponent < ViewComponent::Base
  def initialize(value:)
    @value = value
    super()
  end

  attr_reader :value

  def wording(name) = t("components.evidence_subject.fields.#{name}", default: name.to_s)
end
