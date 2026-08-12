# An eDelivery access point — a member state's Domibus instance, C2 or C3
# depending on which way the message travels.
class AccessPoint
  include ActiveModel::Model
  include ActiveModel::Attributes
  include StrictValidation

  # Fixed by the TDD, and the same on every party of every message.
  ROLE = 'http://sdg.europa.eu/edelivery/gateway'.freeze

  attribute :id, :string
  attribute :type_id, :string

  validates :id, :type_id, presence: true

  # Ours, as the gateway knows it.
  def self.sender = new(**Settings.domibus_sender)
end
