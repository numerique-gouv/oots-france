# An eDelivery access point — a member state's Domibus instance, C2 or C3
# depending on which way the message travels.
#
# `descriptions` and `conforms_to` are published by the Data Service Directory:
# a name for the operator, and the EDM versions the gateway declares — which is
# what decides the version every message of the exchange is written in.
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

  # The EDM version to write for this gateway: `requested` where the caller
  # named one, otherwise the first of the two France speaks; `nil` where the
  # gateway declares versions and none of them is that one.
  #
  # Chapter 4.5.1 §2.2 has the `SpecificationIdentifier` agree with the
  # `ConformsTo` of the Access Service the requester chose, and nothing beyond
  # that ranks the versions a gateway offers: `EdmSpecification::SPOKEN` carries
  # the order, and the first match wins.
  def specification(requested = nil)
    candidates = requested ? [requested] : EdmSpecification::SPOKEN

    candidates.find { |candidate| speaks?(candidate) }
  end

  # A silent access point speaks whatever is asked of it. Chapter 3.1.4 gives
  # `sdg:ConformsTo` a cardinality of 1..n, so an empty list is a directory
  # saying nothing rather than one saying no, and dropping a correspondent on
  # the strength of an omission would answer a directory's fault with ours.
  def speaks?(specification) = conforms_to.empty? || conforms_to.include?(specification.identifier)

  # Ours, as the gateway knows it.
  def self.sender = new(**Settings.domibus_sender)
end
