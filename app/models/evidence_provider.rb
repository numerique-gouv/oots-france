# The organisation holding the evidence — C4 of the four-corner model, the
# "Evidence Provider" of the TDD.
#
# It is described by the access point that reaches it and by one name per
# language, which is what the common services return. Its address is French
# only when it is us; a foreign provider's would come from the DSD, which this
# deployment does not read yet.
class EvidenceProvider
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation

  # Classifications the TDD put on the `sdg:Agent`, by role in the message.
  PROVIDER = 'EP'.freeze
  ERROR_PROVIDER = 'ERRP'.freeze

  attr_accessor :access_point, :descriptions, :address

  def self.french(id:, name:)
    new(
      access_point: AccessPoint.new(id:, type_id: IdentifierScheme::FRENCH),
      descriptions: { 'FR' => name },
    )
  end

  def initialize(attributes = {})
    @access_point = attributes[:access_point]
    @descriptions = attributes[:descriptions] || {}
    @address = attributes[:address] || Address.new
    super()
  end

  validates :access_point, presence: true

  delegate :ebms_identity, to: :access_point

  def access_point_id = access_point&.id
end
