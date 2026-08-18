# The `ExecuteQueryRequest` France sends when it asks another member state for
# a piece of evidence on behalf of a French service provider.
#
# Corners: C1 is the requester, C4 the provider. They swap on the responses,
# which is why each message states them rather than deriving them.
class EvidenceRequestBuilder < ApplicationBuilder
  # Hard-coded. The slot is required by R-EDM-REQ-S011 and must hold at least
  # one element (R-EDM-REQ-S052), but its content should come from the Evidence
  # Broker, which this deployment does not read yet. Stub 7 of
  # `docs/reste_à_faire.md`.
  REQUIREMENT_IDENTIFIER = 'https://sr.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42'.freeze
  REQUIREMENT_NAME = 'Proof of tertiary education diploma/certificate/degree'.freeze

  attr_reader :document_id, :timestamp, :procedure_code, :preview_possible

  def initialize(
    requester:, provider:, beneficiary:, evidence_type:, procedure_code:,
    preview_possible: false, clock: Clock.new, uuid: UuidGenerator.new
  )
    @requester = requester
    @provider = provider
    @beneficiary_person = beneficiary
    @requested_type = evidence_type
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

  def evidence_type = EvidenceTypeBuilder.new(evidence_type: @requested_type).render
end
