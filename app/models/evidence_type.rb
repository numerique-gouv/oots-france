# An evidence type, as the common services describe it: an identifier from the
# Semantic Repository, one title per language, and the format it is distributed
# in.
class EvidenceType
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation
  include SemanticRepositoryAsset
  include Described

  PDF = 'application/pdf'.freeze

  attribute :id, :string
  attribute :distribution_format, :string, default: PDF
  # { 'FR' => 'Justificatif de test', 'EN' => 'Test evidence' }
  attr_reader :descriptions, :details

  validates :id, :distribution_format, presence: true

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @details = attributes.delete(:details) || {}
    super
  end

  def pdf? = distribution_format == PDF
end
