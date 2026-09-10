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
  AlteredBody = Data.define(:render, :document_id) do
    # `R-EDM-REQ-S004`: the qualified form the request carries as its `@id`, and
    # the one a correspondent of the 1.2 line is recognised by, its header naming
    # no exchange.
    def request_id = "urn:uuid:#{document_id}"
  end

  BENEFICIARY = { level_of_assurance: 'Substantial', family_name: 'Dupont', given_name: 'Sophie',
                  date_of_birth: '1965-11-25' }.freeze

  # What a real correspondent would have read from the central directories for a
  # French procedure: the requirement the Evidence Broker returns for FR, and the
  # evidence type classification it leads to. Nothing on the receiving side reads
  # either — `EvidenceProvision::ChooseAnswer` decides on the procedure code and
  # on `evidence_type.pdf?` — so they are here for the request to look like one
  # that was actually discovered.
  REQUIREMENT = 'https://sr.acc.oots.tech.ec.europa.eu/requirements/ffffffff-ffff-ffff-ffff-ffffffffffff'.freeze
  EVIDENCE_TYPE =
    'https://sr.acc.oots.tech.ec.europa.eu/evidencetypeclassifications/FR/869a6748-bfc5-4de6-a0b4-ec0420f6b6a4'.freeze

  def initialize(requester:, gateway: DomibusClient.new, uuid: UuidGenerator.new)
    @requester = requester
    @gateway = gateway
    @uuid = uuid
    @provider = EvidenceProvider.french(**Settings.french_provider_identity)
  end

  # Rendered once and returned, so that submitting the same body twice replays
  # the very request identifier chapter 4.4 forbids reusing.
  def request(procedure_code: ProcedureCode::SYSTEM_CHECK, specification: EdmSpecification.preferred)
    body = EvidenceRequestBuilder.new(
      requester:, provider:, beneficiary:, requirement:, data_service:, procedure_code:, specification:, uuid:,
    )
    rendered = body.render

    AlteredBody.new(render: block_given? ? yield(rendered) : rendered, document_id: body.document_id)
  end

  # Answers the exchange identifier France will open the exchange under, which
  # is what a scenario reads the journal by. Minted here rather than reused, so
  # a replay arrives as its own exchange, as a real one would.
  #
  # The conversation is minted alongside and kept apart, as chapter 4.4 keeps
  # them apart: a correspondent that reused one for the other would let a spec
  # pass against an application that confused them.
  def submit(body, specification: EdmSpecification.preferred)
    exchange_id = uuid.next
    gateway.submit(envelope(body, exchange_id, uuid.next, specification))

    exchange_id
  end

  # A correspondent of the 1.2 line: `R-EDM-ebMS-018` counts two properties
  # there, so the header names no exchange and announces no version, and France
  # mints an identifier of its own. What a scenario reads the journal by is
  # therefore the identifier of the request, which this answers.
  def submit_on_the_earlier_line(body)
    gateway.submit(envelope(body, nil, uuid.next, EdmSpecification::V1_2))

    body.request_id
  end

  private

  attr_reader :requester, :provider, :uuid, :gateway

  def envelope(body, exchange_id, conversation_id, specification)
    OutgoingEnvelopeBuilder.new(
      body:,
      action: EbmsAction::EXECUTE_QUERY_REQUEST,
      recipient: AccessPoint.sender,
      original_sender: requester.ebms_identity,
      final_recipient: provider.ebms_identity,
      conversation_id:,
      exchange_id:,
      specification:,
      uuid:,
    ).render
  end

  def beneficiary = NaturalPerson.new(**BENEFICIARY)

  def requirement
    Requirement.new(id: REQUIREMENT, descriptions: { 'EN' => 'Test requirement' })
  end

  # The evidence type France serves: a PDF, under the classification its own
  # directory entry publishes.
  def data_service
    DataService.new(
      id: '41170824-15d9-4c16-984e-63b75b937b8c',
      evidence_type_classification: EVIDENCE_TYPE,
      distribution_format: EvidenceType::PDF,
      distribution_language: 'EN',
      descriptions: { 'EN' => 'FR - Test Evidence Type' },
    )
  end
end
