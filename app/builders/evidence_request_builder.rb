# The `ExecuteQueryRequest` France sends when it asks another member state for
# a piece of evidence on behalf of a French service provider.
#
# Corners: C1 is the requester, C4 the provider. They swap on the responses,
# which is why each message states them rather than deriving them.
class EvidenceRequestBuilder < ApplicationBuilder
  attr_reader :document_id, :timestamp, :procedure_code, :preview_possible, :requirement

  # R-EDM-REQ-S004: the `id` of a QueryRequest is a UUID prefixed `urn:uuid:`.
  # This qualified form, and not the bare UUID, is what a correspondent echoes
  # back as `@requestId` — so it is the form the exchange is correlated by.
  def request_id = "urn:uuid:#{document_id}"

  def initialize(
    requester:, provider:, beneficiary:, requirement:, data_service:, procedure_code:,
    preview_possible: false, clock: Clock.new, uuid: UuidGenerator.new
  )
    @requester = requester
    @provider = provider
    @beneficiary_person = beneficiary
    @requirement = requirement
    @data_service = data_service
    @procedure_code = procedure_code
    @preview_possible = preview_possible
    @timestamp = clock.now
    @document_id = uuid.next
  end

  protected

  def template_name = 'evidence_request.xml.erb'

  private

  # The requester carries an address and declares itself ER; OOTS-France
  # declares itself IP alongside it, on every request it relays.
  def requester_agent
    AgentBuilder.new(
      identity: @requester.ebms_identity.validate!(:requester),
      names: { @requester.language => @requester.name },
      address: @requester.address,
      classification: EvidenceRequester::REQUESTER,
    ).render
  end

  def intermediary_platform_agent
    platform = EvidenceRequester.intermediary_platform

    AgentBuilder.new(
      identity: platform.ebms_identity,
      names: { platform.language => platform.name },
      classification: EvidenceRequester::INTERMEDIARY_PLATFORM,
    ).render
  end

  # No address and no classification here: on a request, the provider is merely
  # designated, and the TDD ask for neither.
  def provider_agent
    AgentBuilder.new(
      identity: @provider.ebms_identity.validate!(:provider),
      names: @provider.descriptions,
    ).render
  end

  def beneficiary = NaturalPersonBuilder.new(person: @beneficiary_person).render

  def data_service_evidence_type = EvidenceTypeBuilder.new(data_service: @data_service).render
end
