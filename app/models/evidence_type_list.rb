# Evidence types that satisfy a requirement **together**, as the Evidence
# Broker groups them (chapter 3.2.4).
#
# The grouping is the answer's meaning, not a detail of its shape: within one
# list every type is needed, and two lists answering the same requirement are
# alternatives to one another. `EvidenceTypesResponseParser` flattens them for
# the request flow, which keeps the first type it finds — choosing among the
# alternatives is chapter 4.10, and the console is where the choice can at
# least be seen.
class EvidenceTypeList
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Described

  attribute :id, :string
  attribute :country, :string

  attr_reader :descriptions, :evidence_types

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @evidence_types = attributes.delete(:evidence_types) || []
    super
  end
end
