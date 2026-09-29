# The `ExecuteQueryRequest` France sends when it asks another member state for
# a piece of evidence on behalf of a French service provider.
#
# Corners: C1 is the requester, C4 the provider. They swap on the responses,
# which is why each message states them rather than deriving them.
class EvidenceRequestBuilder < ApplicationBuilder
  # R-EDM-REQ-S016: a Query states a `NaturalPerson` or a `LegalPerson`, never
  # both. The subject's own type names the one slot the template writes, so the
  # rule holds by construction rather than by a check made after the fact.
  SUBJECT_SLOTS = {
    NaturalPerson => ['NaturalPerson', NaturalPersonBuilder].freeze,
    LegalPerson => ['LegalPerson', LegalPersonBuilder].freeze,
  }.freeze

  # `R-EDM-REQ-C004` constrains the language of the 1.2 `Procedure` slot without
  # naming one, and that slot carries a procedure code — `R1`, `00` — rather
  # than anything translatable, so the language there is decoration. `EN` is
  # what the published 1.2.5 example writes and what the TDD give as the default
  # choice. 2.0 dropped the element and asks for none.
  PROCEDURE_LANGUAGE = 'EN'.freeze

  # Chapter 4.5.1, table of the request slots: `ReturnLocation` is a
  # `rim:LongText`, 256 characters at most.
  RETURN_LOCATION_LENGTH = 256

  attr_reader :document_id, :procedure_code, :preview_possible, :requirement, :preview_location

  # R-EDM-REQ-S004: the `id` of a QueryRequest is a UUID prefixed `urn:uuid:`.
  # This qualified form, and not the bare UUID, is what a correspondent echoes
  # back as `@requestId` — so it is the form the exchange is correlated by.
  def request_id = "urn:uuid:#{document_id}"

  # Nothing national feeds `associated_documents` yet, and the default is what
  # every caller but the specimen messages takes: `EvidenceResponseParser` reads
  # only the `MainEvidence` of an answer, so an annex or a translation asked for
  # here would be dropped on the way back. OOTS-90 is what makes them readable,
  # and what a national parameter would then be worth publishing for.
  def initialize(
    requester:, provider:, beneficiary:, requirement:, data_service:, procedure_code:,
    associated_documents: [], preview_possible: false, preview_location: nil, return_location: nil,
    specification: EdmSpecification.preferred, clock: Clock.new, uuid: UuidGenerator.new
  )
    @specification = specification
    @requester = requester
    @provider = provider
    @beneficiary_person = beneficiary
    @requirement = requirement
    @data_service = data_service
    @procedure_code = procedure_code
    @associated_documents = associated_documents
    @preview_possible = preview_possible
    @preview_location = preview_location
    @return_location = return_location
    @instant = clock.now
    @document_id = uuid.next
  end

  # The second request of chapter 4.9 §2 step 12 carries, on 2.0, where the
  # correspondent sends the user back: `R-EDM-REQ-S062` pairs the slot with
  # `PreviewLocation`. The 1.2 line has no such slot — `R-EDM-REQ-S019` @ 1.2.5
  # closes the list without it — and the address travels in the link instead.
  def return_location
    return unless @return_location.present? && specification.return_location_slot?
    return @return_location if @return_location.length <= RETURN_LOCATION_LENGTH

    raise ConfigurationError, I18n.t('builders.evidence_request_builder.return_location_too_long',
      length: @return_location.length, limit: RETURN_LOCATION_LENGTH)
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

  def subject_slot_name = subject_slot.first

  def beneficiary = subject_slot.last.new(person: @beneficiary_person).render

  # `fetch` rather than a default: a subject of an unknown type must fail the
  # construction, where a silent fallback would send a request stating whom it
  # is about wrongly, or not at all. `ConfigurationError` and not the bare
  # `KeyError`, which no interactor rescues — it would leave the caller a 500
  # with no exception element and no line in the exchange log.
  def subject_slot
    @subject_slot ||= SUBJECT_SLOTS.fetch(@beneficiary_person.class) do
      raise ConfigurationError,
        I18n.t('builders.evidence_request_builder.unknown_subject', type: @beneficiary_person.class)
    end
  end

  def data_service_evidence_type
    EvidenceTypeBuilder.new(
      data_service: @data_service, associated_documents: @associated_documents, specification:,
    ).render
  end
end
