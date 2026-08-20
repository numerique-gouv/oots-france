# A correspondent whose requests France did not write itself.
#
# The end-to-end exchange loops through the single gateway of the example PMode,
# so France otherwise only ever receives requests it built: conformant by
# construction, and always under a fresh identifier. The refusals chapters 4.6
# and 4.4 require would therefore never be exercised anywhere the transport is
# real — which is the one thing these scenarios exist for.
#
# Builds with the repository's own builders and alters the rendered RegRep body,
# the gesture `envelope_with_body` makes in the unit suite, then submits through
# the gateway as any correspondent would.
class FakeCorrespondent
  # `OutgoingEnvelopeBuilder` asks a body to render itself and to name the
  # identifier its payload reference is minted from. A body altered after
  # rendering is no longer a builder, so it answers both on its own.
  AlteredBody = Data.define(:render, :document_id)

  BENEFICIARY = { family_name: 'Dupont', given_name: 'Sophie', date_of_birth: '1965-11-25' }.freeze

  def initialize(requester:, gateway: DomibusClient.new, uuid: UuidGenerator.new)
    @requester = requester
    @gateway = gateway
    @uuid = uuid
    @provider = EvidenceProvider.french(**Settings.french_provider_identity)
  end

  # Rendered once and returned, so that submitting the same body twice replays
  # the very request identifier chapter 4.4 forbids reusing.
  def request(procedure_code: ProcedureCode::SYSTEM_CHECK)
    body = EvidenceRequestBuilder.new(
      requester:, provider:, beneficiary:, requirement:, data_service:, procedure_code:, uuid:,
    )
    rendered = body.render

    AlteredBody.new(render: block_given? ? yield(rendered) : rendered, document_id: body.document_id)
  end

  # Answers the conversation identifier France will open the exchange under,
  # which is what a scenario reads the journal by. Minted here rather than
  # reused, so a replay arrives as its own exchange, as a real one would.
  def submit(body)
    conversation_id = uuid.next
    gateway.submit(envelope(body, conversation_id))

    conversation_id
  end

  private

  attr_reader :requester, :provider, :uuid, :gateway

  def envelope(body, conversation_id)
    OutgoingEnvelopeBuilder.new(
      body:,
      action: EbmsAction::EXECUTE_QUERY_REQUEST,
      recipient: AccessPoint.sender,
      original_sender: requester.ebms_identity,
      final_recipient: provider.ebms_identity,
      conversation_id:,
      uuid:,
    ).render
  end

  def beneficiary = NaturalPerson.new(**BENEFICIARY)

  def requirement
    Requirement.new(id: FakeCommonServices::REQUIREMENT, descriptions: { 'EN' => 'Test requirement' })
  end

  # The evidence type France serves: a PDF, under the classification its own
  # directory entry publishes.
  def data_service
    DataService.new(
      id: '41170824-15d9-4c16-984e-63b75b937b8c',
      evidence_type_classification: FakeCommonServices::EVIDENCE_TYPE,
      distribution_format: EvidenceType::PDF,
      distribution_language: 'EN',
      descriptions: { 'EN' => 'FR - Test Evidence Type' },
    )
  end
end
