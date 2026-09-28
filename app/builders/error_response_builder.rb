# The `ExceptionResponse` France returns when it cannot serve a request.
#
# Corners are inverted with respect to the request: the provider — us — is C1,
# and the requester that asked is C4. The provider is classified `ERRP` here,
# not `EP`: it is answering for an error, not delivering evidence.
#
# Given a `preview_location`, it is the `EDM:ERR:0002` of chapter 4.9 §2 step 9,
# sending the user to France's preview space.
class ErrorResponseBuilder < ApplicationBuilder
  # Chapter 4.9 §1 advises against any other method, and France serves the
  # space it issues in `GET` alone.
  PREVIEW_METHOD = 'GET'.freeze

  # `R-EDM-ERR-C020` takes the languages from the `LanguageCode` list. Chapter
  # 4.9 §4 asks for one broadly understood language at least: English, and the
  # French of the space itself.
  PREVIEW_LANGUAGES = %w[EN FR].freeze

  attr_reader :request_id, :document_id, :exception, :preview_location

  def initialize(
    requester:, exception:, request_id:, provider: nil, preview_location: nil,
    specification: EdmSpecification.preferred, clock: Clock.new, uuid: UuidGenerator.new
  )
    @specification = specification
    @requester = requester
    @provider = provider || EvidenceProvider.french
    @exception = exception
    @request_id = request_id
    @preview_location = preview_location
    @instant = clock.now
    @document_id = uuid.next
  end

  # `R-EDM-ERR-S031` asks for it on the 1.2 line, and 2.0 removed the slot.
  def preview_method? = preview_location.present? && specification.preview_method_slot?

  def preview_descriptions
    PREVIEW_LANGUAGES.index_with do |language|
      I18n.t("builders.error_response_builder.preview_description.#{language.downcase}")
    end
  end

  protected

  def template_name = 'error_response.xml.erb'

  private

  def provider_agent
    AgentBuilder.new(
      identity: @provider.ebms_identity.validate!(:french_provider),
      names: @provider.descriptions,
      address: @provider.address,
      classification: EvidenceProvider::ERROR_PROVIDER,
    ).render
  end

  # No address and no classification on the requester of an error response: the
  # TDD require them on the agent answering, not on the one being answered.
  def requester_agent
    AgentBuilder.new(
      identity: @requester.ebms_identity.validate!(:requester),
      names: { @requester.language => @requester.name },
    ).render
  end
end
