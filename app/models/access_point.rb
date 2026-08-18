# An eDelivery access point — a member state's Domibus instance, C2 or C3
# depending on which way the message travels.
#
# `descriptions` and `conforms_to` are published by the Data Service Directory
# and read by nothing a message contains: a name for the operator, and the EDM
# versions the gateway declares, which is what the `specification` parameter of
# the DSD query filters on.
class AccessPoint
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation
  include Described

  # Fixed by the TDD, and the same on every party of every message.
  ROLE = 'http://sdg.europa.eu/edelivery/gateway'.freeze

  attribute :id, :string
  attribute :type_id, :string

  attr_reader :descriptions, :conforms_to

  validates :id, :type_id, presence: true

  def initialize(attributes = {})
    @descriptions = attributes.delete(:descriptions) || {}
    @conforms_to = attributes.delete(:conforms_to) || []
    super
  end

  # Ours, as the gateway knows it.
  def self.sender = new(**Settings.domibus_sender)
end
