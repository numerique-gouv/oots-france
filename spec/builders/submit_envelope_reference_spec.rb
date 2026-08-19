require 'rails_helper'

# The eight reference envelopes of `spec/fixtures/reference/soap/`, which the
# builders must reproduce. Their provenance and the two divergences they carry
# are documented in `spec/fixtures/README.md`, which owns that.
#
# What the gateway receives is the envelope, not the RegRep body alone: a
# dropped `soap:Header`, a wrong namespace URI or a misplaced payload would pass
# every other builder spec in this directory.
RSpec.describe 'Les enveloppes soumises au plugin WS' do
  let(:frozen_clock) { instance_double(Clock, now: '2026-08-06T10:00:00.000Z') }

  # Every identity is supplied here rather than read from the environment. The
  # references are frozen under one gateway identity, and a deployment's `.env`
  # carries another — reading it would compare the builders against a
  # configuration instead of against the reference, and the suite would then
  # pass or fail depending on which `.env.oots` `make test` mounts.
  let(:french_access_point) do
    AccessPoint.new(id: 'AP_FR_01', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots')
  end
  # One generator shared by the body and the header: they draw from the same
  # counter, and the payload the header declares is the very document the body
  # carries.
  let(:uuid) { Oots::SequentialUuids.new }

  before do
    allow(Settings).to receive_messages(
      identifier_suffix: 'oots.eu',
      french_provider_identity: { id: '00000000000001', name: 'Direction interministérielle du numérique' },
    )
  end

  it 'renders the submission of a request as the reference envelope has it' do
    expect(submission_of(request_body, EbmsAction::EXECUTE_QUERY_REQUEST))
      .to be_equivalent_xml_to(reference_envelope('requete.soumission'))
  end

  {
    'erreur' => EdmException::OBJECT_NOT_FOUND,
    'erreurRequeteInvalide' => EdmException::INVALID_REQUEST,
    'erreurCapaciteNonSupportee' => EdmException::UNSUPPORTED_CAPABILITY,
  }.each do |fixture, exception|
    it "renders the submission of the #{exception.code} response as the reference has it" do
      expect(submission_of(error_body(exception), EbmsAction::EXCEPTION_RESPONSE))
        .to be_equivalent_xml_to(reference_envelope("#{fixture}.soumission"))
    end
  end

  # The only envelope carrying two payloads — the RegRep body and the evidence
  # itself. It exercises what none of the others do: the link between the
  # payload the ebMS header declares and the one the body carries, and a
  # payload the matcher cannot decode sitting beside one it can.
  it 'renders the submission of a response with its evidence as the reference has it' do
    # Drawn before the body: the identifiers share one counter, and their order
    # is what ties the metadata to the bytes.
    attachment = Attachment.new("cid:#{uuid.next}@pdf.oots.fr", Base64.strict_encode64(evidence))

    expect(submission_of(response_body(attachment), EbmsAction::EXECUTE_QUERY_RESPONSE, attachment:))
      .to be_equivalent_xml_to(reference_envelope('reponse.soumission'))
  end

  describe 'the service requests' do
    it 'lists the pending messages as the reference has it' do
      expect(ListPendingMessagesBuilder.new.render)
        .to be_equivalent_xml_to(reference_envelope('listeMessagesEnAttente'))
    end

    it 'filters that listing on a conversation as the reference has it' do
      expect(ListPendingMessagesBuilder.new(conversation_id: CONVERSATION_ID).render)
        .to be_equivalent_xml_to(reference_envelope('listeMessagesEnAttente.filtree'))
    end

    it 'retrieves a message as the reference has it' do
      expect(RetrieveMessageBuilder.new(message_id: '1a2b3c4d-0000-4000-8000-000000009999@oots.eu').render)
        .to be_equivalent_xml_to(reference_envelope('recuperationMessage'))
    end
  end

  CONVERSATION_ID = 'e0a6a5b7-6b2e-4b9c-9a63-8f0c6d3a1b24'.freeze
  REQUEST_ID = 'urn:uuid:4ffb5281-179d-4578-adf2-39fd13ccc797'.freeze

  # Assembled by the very class the interactors use, so the frozen references
  # judge the assembly and not a copy of it made for the spec.
  def submission_of(body, action, attachment: EmptyAttachment.new)
    OutgoingEnvelopeBuilder.new(
      body:,
      attachment:,
      action:,
      recipient: german_access_point,
      original_sender: original_sender(action),
      final_recipient: final_recipient(action),
      conversation_id: CONVERSATION_ID,
      sender: french_access_point,
      clock: frozen_clock,
      uuid:,
    ).render
  end

  def request_body
    EvidenceRequestBuilder.new(
      requester:, provider: german_provider, beneficiary:, requirement:, data_service:,
      procedure_code: ProcedureCode::STUDENT_GRANT,
      clock: frozen_clock, uuid:,
    )
  end

  def evidence = Rails.root.join('assets/drapeau.pdf').binread

  def response_body(attachment)
    SystemCheckResponseBuilder.new(
      requester:, beneficiary:, evidence_type:, attachment:,
      request_id: REQUEST_ID, clock: frozen_clock, uuid:,
    )
  end

  def error_body(exception)
    ErrorResponseBuilder.new(
      requester:, exception:, request_id: REQUEST_ID,
      clock: frozen_clock, uuid:,
    )
  end

  def original_sender(action)
    action == EbmsAction::EXECUTE_QUERY_REQUEST ? requester.ebms_identity : french_provider.ebms_identity
  end

  def final_recipient(action)
    action == EbmsAction::EXECUTE_QUERY_REQUEST ? german_provider.ebms_identity : requester.ebms_identity
  end

  def requester
    EvidenceRequester.french(id: '00000000000002', name: "Ministère de l'enseignement supérieur")
  end

  def french_provider = EvidenceProvider.french(**Settings.french_provider_identity)

  def german_provider
    EvidenceProvider.new(
      identifier: EbmsIdentity.new(id: 'DE73524311', type_id: 'urn:cef.eu:names:identifier:EAS:9930'),
      access_point: german_access_point,
      descriptions: { 'EN' => 'Civil Registration Office Berlin I' },
    )
  end

  def german_access_point
    AccessPoint.new(id: 'AP_DE_01', type_id: 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:oots')
  end

  def beneficiary
    NaturalPerson.new(
      eidas_identifier: 'FR/DE/123123123', family_name: 'Dupont', given_name: 'Jean', date_of_birth: '1992-10-22',
    )
  end

  def evidence_type
    EvidenceType.new(
      id: 'https://sr.oots.tech.ec.europa.eu/evidencetypeclassifications/DE/ca8afed6-2dc0-422a-a931-d21c3d8d370e',
      descriptions: { 'EN' => 'Certificate of Birth' },
      distribution_format: EvidenceType::PDF,
    )
  end

  def requirement
    Requirement.new(
      id: 'https://sr.oots.tech.ec.europa.eu/requirements/f8a6a284-34e9-42c7-9733-63b5c4f4aa42',
      descriptions: { 'EN' => 'Proof of tertiary education diploma/certificate/degree' },
      details: { 'EN' => 'Proof that the person holds a diploma awarded by a tertiary education institution.' },
    )
  end

  def data_service
    DataService.new(
      id: '41170824-15d9-4c16-984e-63b75b937b8c',
      evidence_type_classification: evidence_type.id,
      distribution_format: EvidenceType::PDF,
      distribution_language: 'EN',
      descriptions: evidence_type.descriptions,
      details: { 'EN' => 'Birth certificate issued by the civil registration office.' },
    )
  end
end
