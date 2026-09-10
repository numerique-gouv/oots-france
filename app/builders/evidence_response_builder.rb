# The `ExecuteQueryResponse` France returns for the procedures it serves with an
# actual document. No slot of this response names the procedure it answers, so
# nothing rendered here varies with it.
#
# Corners are inverted with respect to the request, as on the error response:
# the provider answering is C1, the requester that asked is C4. The provider is
# classified `EP` here, and its slot is a collection, where the requester's is a
# single value — an asymmetry the TDD impose, not one chosen here.
class EvidenceResponseBuilder < ApplicationBuilder
  # Hard-coded: France holds no real evidence to date it. Stub, tracked as
  # OOTS-84.
  ISSUING_DATE = '1970-03-03'.freeze

  attr_reader :request_id, :timestamp, :beneficiary, :evidence_type, :attachment,
    :document_id, :package_id, :extrinsic_object_id, :evidence_id, :classification_id

  def initialize(
    requester:, beneficiary:, evidence_type:, attachment:, request_id:,
    provider: nil, specification: EdmSpecification.preferred, clock: Clock.new, uuid: UuidGenerator.new
  )
    @specification = specification
    @requester = requester
    @provider = provider || EvidenceProvider.french(**Settings.french_provider_identity)
    @beneficiary = beneficiary
    @evidence_type = evidence_type
    @attachment = attachment
    @request_id = request_id
    @timestamp = clock.now
    @document_id = uuid.next
    # Drawn whatever the version, though only the 2.0 response carries the
    # package and the classification: a sequence that skipped them would give
    # the same message two different sets of identifiers depending on the
    # version, and nothing would then be comparable between the two.
    @package_id = uuid.next
    @extrinsic_object_id = uuid.next
    @evidence_id = uuid.next
    @classification_id = uuid.next
  end

  protected

  # The one template doubled by version — see `ApplicationBuilder#versioned`.
  def template_name = versioned('evidence_response')

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

  # The distribution France served, and never one copied back from the
  # request: `R-EDM-REQ-C032` lets a request name several — the human-readable
  # fallback of chapter 4.5.1 §3.5 beside a structured format — so there is no
  # single format to echo.
  #
  # What that element means in a response is settled by `R-EDM-RESP-C050`,
  # which refuses a `sdg:ConformsTo` beside a PDF: a distribution answering for
  # a document nobody sent could carry any data model, so the rule only makes
  # sense of one describing the document carried. It constrains an
  # `EvidenceMetadata` slot one `rim:RegistryObject` shallower than the one
  # this response writes, so it is read here for what it settles, not applied.
  def served_format = Attachment::MIME_TYPE
end
