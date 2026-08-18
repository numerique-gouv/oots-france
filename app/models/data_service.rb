# What the Data Service Directory publishes for one evidence type in one
# country (chapter 3.1.4): the organisations able to deliver it, and the
# identifier the directory itself assigns to the pairing.
#
# That identifier is what an outgoing request carries in its
# `DataServiceEvidenceType` slot, where stub 7 of `docs/reste_à_faire.md` still
# writes a constant. Read here, not yet written there.
class DataService
  include ActiveModel::Model
  include ActiveModel::Attributes
  include Described

  attribute :id, :string
  attribute :evidence_type_classification, :string
  attribute :distribution_format, :string
  attribute :level_of_assurance, :string

  attr_reader :descriptions, :details, :providers

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @details = attributes.delete(:details) || {}
    @providers = attributes.delete(:providers) || []
    super
  end
end
