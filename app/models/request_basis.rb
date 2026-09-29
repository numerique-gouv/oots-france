# What the second request of a preview repeats of the first, apart from its
# subject — chapter 4.9 §2 step 12: « For all rim:Slots except IssueDateTime,
# this evidence request have the same content as the first request ».
#
# Kept on the exchange from the first emission rather than asked of the
# directories again: « the same content » is what they answered then, and a
# directory may have changed, or its cache expired, between the two round
# trips. Nothing here is personal — the subject is the portal's to give again.
class RequestBasis
  attr_reader :requirement, :provider, :recipient, :data_service, :evidence_type, :preview_possible

  def initialize(requirement:, provider:, recipient:, data_service:, evidence_type:, preview_possible:)
    @requirement = requirement
    @provider = provider
    @recipient = recipient
    @data_service = data_service
    @evidence_type = evidence_type
    @preview_possible = preview_possible
  end

  def self.from_h(stored)
    recipient = access_point(stored.fetch('recipient'))

    new(
      requirement: Requirement.new(**stored.fetch('requirement').symbolize_keys),
      provider: provider(stored.fetch('provider'), recipient),
      recipient:,
      data_service: DataService.new(**stored.fetch('data_service').symbolize_keys),
      evidence_type: EvidenceType.new(id: stored.fetch('evidence_type_id')),
      preview_possible: stored.fetch('preview_possible'),
    )
  end

  def self.provider(stored, access_point)
    EvidenceProvider.new(
      identifier: EbmsIdentity.new(**stored.fetch('identifier').symbolize_keys),
      descriptions: stored.fetch('descriptions'),
      address: Address.new(**stored.fetch('address').symbolize_keys),
      access_point:,
    )
  end

  def self.access_point(stored) = AccessPoint.new(**stored.symbolize_keys)

  private_class_method :provider, :access_point

  # By value: Active Record compares what it loaded to what it holds to know
  # whether the column changed, and two readings of one row are two objects.
  def ==(other) = other.is_a?(RequestBasis) && other.to_h == to_h
  alias eql? ==

  delegate :hash, to: :to_h

  def to_h
    {
      'requirement' => requirement_h,
      'provider' => provider_h,
      'recipient' => recipient_h,
      'data_service' => data_service_h,
      'evidence_type_id' => evidence_type.id,
      'preview_possible' => preview_possible,
    }
  end

  # The column is `jsonb`, which serialises natively and so refuses Rails'
  # `serialize`: an attribute type is what turns the stored hash back into the
  # objects the builder takes.
  class Type < ActiveRecord::Type::Json
    def cast(value) = value.is_a?(Hash) ? RequestBasis.from_h(value.deep_stringify_keys) : value

    def deserialize(value) = cast(super)

    def serialize(value) = super(value.is_a?(RequestBasis) ? value.to_h : value)
  end

  private

  def requirement_h = { 'id' => requirement.id, 'descriptions' => requirement.descriptions, 'details' => requirement.details }

  def recipient_h = { **recipient.attributes, 'descriptions' => recipient.descriptions, 'conforms_to' => recipient.conforms_to }

  def data_service_h
    { **data_service.attributes, 'descriptions' => data_service.descriptions, 'details' => data_service.details }
  end

  def provider_h
    {
      'identifier' => provider.identifier.attributes,
      'descriptions' => provider.descriptions,
      'address' => provider.address.attributes,
    }
  end
end
