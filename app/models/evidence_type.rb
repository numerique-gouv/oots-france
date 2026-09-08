# An evidence type, as the common services describe it: an identifier from the
# Semantic Repository, one title per language, and the formats it is distributed
# in.
class EvidenceType
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation
  include SemanticRepositoryAsset
  include Described

  PDF = 'application/pdf'.freeze

  attribute :id, :string
  # { 'FR' => 'Justificatif de test', 'EN' => 'Test evidence' }
  attr_reader :descriptions, :details

  # `R-EDM-REQ-C032` (FATAL) asks for `sdg:DistributedAs` « at least once », and
  # chapter 4.5.1 §3.5 names what a second one is for: « an additional
  # sdg:DistributedAs element may be used to request a human-readable format
  # (e.g. JPEG, PNG, SVG, or PDF) for the same sdg:DataServiceEvidenceType ».
  # Outside the attribute API for want of an `ActiveModel` `Array` type, as
  # `descriptions` and `details` are.
  attr_reader :distribution_formats

  # Presence and nothing more, on a collection: an entry may legitimately be
  # nil. `R-EDM-REQ-C032` counts the `sdg:DistributedAs` elements and says
  # nothing of what they contain, so a request naming one without a format
  # breaks no rule, and `EvidenceRequestParser` reads it as the silence it is.
  # Asking each entry to be named would hold a requested type to an invariant
  # the specification does not give it.
  #
  # Only an announced type is ever validated — `validate!` is called on the
  # Evidence Broker's answer alone. A requested one carries its own refusal,
  # in the parser, which is the only place that can name `R-EDM-REQ-C032` in
  # the `detail` the correspondent receives.
  validates :id, :distribution_formats, presence: true

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @details = attributes.delete(:details) || {}
    @distribution_formats = attributes.delete(:distribution_formats) || [PDF]
    super
  end

  # Any of them: a request naming several distributions asks for one document in
  # several shapes, and France serves the one it holds.
  def pdf? = distribution_formats.include?(PDF)
end
