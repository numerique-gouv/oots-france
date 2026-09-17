# The `ExecuteQueryResponse` France returns when it will not serve the document
# now. `R-EDM-RESP-S006` allows two statuses and this builder always writes the
# second; `R-EDM-RESP-S045` then requires the date by which the evidence will be
# available, and `R-EDM-RESP-S007` the `RegistryObjectList`, which chapter 4.5.2
# leaves empty for want of anything available.
#
# Corners are inverted with respect to the request, as on the two other
# answers, and the agents are classified the same way.
class DeferredResponseBuilder < ApplicationBuilder
  # Hard-coded: France defers no real document, so the announced date is an
  # offset from the answer rather than an availability anyone computed. Stub,
  # tracked as OOTS-91.
  DEFERRAL = 1.day

  attr_reader :request_id, :available_at, :document_id

  def initialize(
    requester:, request_id:, provider: nil,
    specification: EdmSpecification.preferred, clock: Clock.new, uuid: UuidGenerator.new
  )
    @specification = specification
    @requester = requester
    @provider = provider || EvidenceProvider.french
    @request_id = request_id
    @instant = clock.now
    # Counted from that one reading, so the two instants the message carries
    # cannot come from two.
    @available_at = @instant.getutc + DEFERRAL
    @document_id = uuid.next
  end

  protected

  def template_name = 'deferred_response.xml.erb'

  private

  def provider_agent
    AgentBuilder.new(
      identity: @provider.ebms_identity.validate!(:french_provider),
      names: @provider.descriptions,
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
end
