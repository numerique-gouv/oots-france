# The `ExecuteQueryResponse` France returns for procedure `00`, the OOTS system
# check — the only procedure it serves with an actual document today.
#
# Corners are inverted with respect to the request, as on the error response:
# the provider answering is C1, the requester that asked is C4. The provider is
# classified `EP` here, and its slot is a collection, where the requester's is a
# single value — an asymmetry the TDD impose, not one chosen here.
class SystemCheckResponseBuilder < ApplicationBuilder
  # Hard-coded: France holds no real evidence to date it. Stub, tracked as
  # OOTS-84.
  ISSUING_DATE = '1970-03-03'.freeze

  attr_reader :request_id, :timestamp, :beneficiary, :evidence_type, :attachment,
    :document_id, :package_id, :extrinsic_object_id, :evidence_id, :classification_id

  def initialize(
    requester:, beneficiary:, evidence_type:, attachment:, request_id:,
    provider: nil, clock: Clock.new, uuid: UuidGenerator.new
  )
    @requester = requester
    @provider = provider || EvidenceProvider.french(**Settings.french_provider_identity)
    @beneficiary = beneficiary
    @evidence_type = evidence_type
    @attachment = attachment
    @request_id = request_id
    @timestamp = clock.now
    @document_id = uuid.next
    @package_id = uuid.next
    @extrinsic_object_id = uuid.next
    @evidence_id = uuid.next
    @classification_id = uuid.next
  end

  protected

  def template_name = 'system_check_response.xml.erb'

  private

  def provider_identity = @provider.ebms_identity.validate!(:french_provider)

  def provider_names = @provider.descriptions

  def provider_agent
    AgentBuilder.new(
      identity: provider_identity,
      names: provider_names,
      address: @provider.address,
      classification: EvidenceProvider::PROVIDER,
    ).render
  end

  def requester_agent
    AgentBuilder.new(
      identity: @requester.ebms_identity.validate!(:requester),
      names: { @requester.language => @requester.name },
    ).render
  end

  # `sdg:IsAbout` is an `xs:choice`, and the branch is the subject's to name:
  # the builder picks it from the type it is given.
  def evidence_subject = EvidenceSubjectBuilder.new(beneficiary:).render
end
