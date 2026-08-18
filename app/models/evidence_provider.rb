# The organisation holding the evidence — C4 of the four-corner model, the
# "Evidence Provider" of the TDD.
#
# Its identity and its access point are two different things, and the DSD
# returns them as such: `sdg:Publisher` names the organisation, which is what
# a message designates as C4, where `sdg:AccessService` names the gateway that
# carries the message to it. A Finnish provider answers as `FIKEHA02` behind
# the access point `AP_FI_03`.
class EvidenceProvider
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation
  include Described

  # Classifications the TDD put on the `sdg:Agent`, by role in the message.
  PROVIDER = 'EP'.freeze
  ERROR_PROVIDER = 'ERRP'.freeze

  attr_accessor :identifier, :access_point, :descriptions, :address

  # Answering, France is its own C4 and the message goes back to whoever sent
  # it: there is no access point to resolve.
  def self.french(id:, name:)
    new(
      identifier: EbmsIdentity.new(id:, type_id: IdentifierScheme::FRENCH),
      descriptions: { 'FR' => name },
    )
  end

  def initialize(attributes = {})
    @identifier = attributes[:identifier]
    @access_point = attributes[:access_point]
    @descriptions = attributes[:descriptions] || {}
    @address = attributes[:address] || Address.new
    super()
  end

  validates :identifier, presence: true

  def ebms_identity = identifier
end
