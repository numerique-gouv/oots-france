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

  attr_reader :document_id, :timestamp, :procedure_code, :preview_possible, :requirement

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
    associated_documents: [], preview_possible: false, clock: Clock.new, uuid: UuidGenerator.new
  )
    @requester = requester
    @provider = provider
    @beneficiary_person = beneficiary
    @requirement = requirement
    @data_service = data_service
    @procedure_code = procedure_code
    @associated_documents = associated_documents
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
    EvidenceTypeBuilder.new(data_service: @data_service, associated_documents: @associated_documents).render
  end
end
