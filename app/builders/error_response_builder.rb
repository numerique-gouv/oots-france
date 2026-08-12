# The `ExceptionResponse` France returns when it cannot serve a request.
#
# Corners are inverted with respect to the request: the provider — us — is C1,
# and the requester that asked is C4. The provider is classified `ERRP` here,
# not `EP`: it is answering for an error, not delivering evidence.
#
# The template accepts a `PreviewLocation` slot, which the application it
# replaces could not emit at all. It is what `EDM:ERR:0002` needs, and chapter
# 4.9 on the provider side will need it; nothing emits it yet.
class ErrorResponseBuilder < ApplicationBuilder
  attr_reader :request_id, :document_id, :timestamp, :exception, :preview_location

  def initialize(
    requester:, exception:, request_id:, provider: nil, preview_location: nil,
    clock: Clock.new, uuid: UuidGenerator.new
  )
    @requester = requester
    @provider = provider || EvidenceProvider.french(**Settings.french_provider_identity)
    @exception = exception
    @request_id = request_id
    @preview_location = preview_location
    @timestamp = clock.now
    @document_id = uuid.next
  end

  protected

  def template_name = 'error_response.xml.erb'

  private

  def provider_agent
    AgentBuilder.new(
      identity: @provider.ebms_identity.validate!('Le fournisseur français'),
      names: @provider.descriptions,
      address: @provider.address,
      classification: EvidenceProvider::ERROR_PROVIDER,
    ).render
  end

  # No address and no classification on the requester of an error response: the
  # TDD require them on the agent answering, not on the one being answered.
  def requester_agent
    AgentBuilder.new(
      identity: @requester.ebms_identity.validate!('Le requêteur'),
      names: { @requester.language => @requester.name },
    ).render
  end
end
