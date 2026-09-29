require 'rails_helper'

# The two requests of chapter 4.9 on the side that asks, run through their two
# chains: the first by `Fetch`, the second by this one, the correspondent's
# exception written in between as `SettleExchange` would.
RSpec.describe EvidenceRequest::ConfirmPreview do
  include OotsNamespaces

  let(:gateway) { gateway_accepting_submissions }
  let(:envelopes) { [] }
  let(:access_point) { build(:access_point, :foreign, conforms_to: [specification.identifier]) }
  let(:specification) { EdmSpecification::V2_0 }
  let(:uuid) { Oots::SequentialUuids.new }
  let(:requesters) { instance_double(Directories::EvidenceRequesters, find: build(:evidence_requester)) }
  let(:preview) { 'https://previsualisation.example.si/espace?session=abc' }

  let(:common_services) do
    instance_double(Directories::CommonServices,
      required_evidence_for_procedure: [Directories::CommonServices::RequiredEvidence.new(
        requirement: build(:requirement), evidence_types: [build(:evidence_type)],
      )],
      data_service: build(:data_service, providers: [build(:evidence_provider, access_point:)]))
  end

  let(:first) do
    EvidenceRequest::Fetch.call(
      requester_id: '00000000000002', conversation_id: nil, requesters:, encrypted_beneficiary: 'un-jeton',
      procedure_code: ProcedureCode::SYSTEM_CHECK, country_code: 'SI', preview_possible: true,
      common_services:, gateway:, uuid:, audit_trail: AuditTrail.new,
    )
  end

  before do
    allow(BeneficiaryToken).to receive(:new)
      .and_return(instance_double(BeneficiaryToken, beneficiary: build(:natural_person)))
    allow(gateway).to receive(:submit) do |envelope|
      envelopes << envelope
      instance_double(SubmittedMessageParser, message_id: 'message-passerelle')
    end
    first
  end

  def confirm(method: nil)
    exchange = Exchange.find(first.exchange.id)
    exchange.preview_required!(preview, method:)

    described_class.call(
      exchange:, requester_id: exchange.evidence_requester_id, encrypted_beneficiary: 'un-jeton',
      resume_location: 'https://demarche.example.fr/reprise', requesters:, gateway:, uuid:,
      audit_trail: AuditTrail.new,
    )
  end

  def submissions = envelopes.map { |envelope| Nokogiri::XML(envelope) }

  def body_of(envelope) = Nokogiri::XML(Base64.decode64(text_at(envelope, '//payload/value')))

  def slots_of(body)
    all(body, '/*/rim:Slot').to_h { |slot| [attribute(slot, 'name'), slot.to_s] }
  end

  def query_of(body) = at(body, '//query:Query').to_s

  def property_of(envelope, name) = text_at(envelope, "//eb:Property[@name=\"#{name}\"]")

  it 'emits the second request and reopens the exchange as sent' do
    second = confirm

    expect(second).to be_success
    expect(submissions.size).to eq(2)
    expect(second.exchange.reload).to have_attributes(status: 'sent', preview_confirmed_at: be_present)
  end

  # CA4 of OOTS-67: « For all rim:Slots except IssueDateTime, this evidence
  # request have the same content as the first request » — the subject
  # included, which nothing kept between the two.
  it 'repeats the first request, subject included, with the two addresses added' do
    confirm
    before, after = submissions.map { |envelope| body_of(envelope) }

    expect(slots_of(after).except('IssueDateTime', 'PreviewLocation', 'ReturnLocation'))
      .to eq(slots_of(before).except('IssueDateTime'))
    expect(query_of(after)).to eq(query_of(before))
    expect(text_at(after, "//rim:Slot[@name='PreviewLocation']//rim:Value")).to eq(preview)
    expect(text_at(after, "//rim:Slot[@name='ReturnLocation']//rim:Value"))
      .to start_with("#{Settings.oots_france_url}/retour/")
  end

  # CA4 again: chapter 4.4 §4.1 refuses a request identifier used before, and
  # chapter 4.7 §2.5.2 has the second request reuse the `ExchangeId`.
  it 'gives the second request an identifier of its own, under the same exchange and conversation' do
    second = confirm
    before, after = submissions

    expect(attribute(body_of(after).root, 'id')).not_to eq(attribute(body_of(before).root, 'id'))
    expect(property_of(after, 'ExchangeId')).to eq(property_of(before, 'ExchangeId'))
    expect(text_at(after, '//eb:ConversationId')).to eq(text_at(before, '//eb:ConversationId'))
    # CA11: the answer is correlated by the identifier of the second request.
    expect(second.exchange.reload.request_id).to eq(attribute(body_of(after).root, 'id'))
  end

  # Nothing of the subject is written between the two requests: the exchange
  # holds no column that could.
  it 'writes nothing of the beneficiary on the exchange' do
    confirm

    expect(Exchange.find(first.exchange.id).attributes.to_json).not_to include('Dupont')
  end

  # RG16 of OOTS-67: the requester's « URL visited by user » is the link it
  # presented.
  it 'journals the second request with the link presented to the user' do
    confirm

    expect(AuditEvent.where(event_type: 'request_sent').order(:occurred_at).last.preview_location).to eq(preview)
  end

  it 'answers with the link to present' do
    expect(confirm.preview_link).to have_attributes(address: preview, http_method: 'GET', body: nil)
  end

  it 'refuses a second confirmation, and emits nothing more' do
    confirm
    again = described_class.call(
      exchange: Exchange.find(first.exchange.id), requester_id: '00000000000002', encrypted_beneficiary: 'un-jeton',
      resume_location: 'https://demarche.example.fr/reprise', requesters:, gateway:, uuid:, audit_trail: AuditTrail.new,
    )

    expect(again.error).to include(key: :preview_not_awaited)
    expect(submissions.size).to eq(2)
  end

  # A token that cannot be read leaves the exchange where it was, so that the
  # portal may try again.
  it 'leaves the exchange awaiting its confirmation when the token cannot be read' do
    allow(BeneficiaryToken).to receive(:new).and_raise(InvalidTokenError, 'illisible')

    expect(confirm.error).to include(key: :invalid_token)
    expect(Exchange.find(first.exchange.id).status).to eq('preview_required')
  end

  # CA12 of OOTS-67: on 1.2 the return address travels in the link, and the
  # header carries two properties.
  context 'when the exchange runs on the 1.2 line' do
    let(:specification) { EdmSpecification::V1_2 }

    it 'names no return address in the request, and appends it to the link' do
      second = confirm(method: 'GET')
      after = submissions.last

      expect(slots_of(body_of(after)).keys).not_to include('ReturnLocation', 'PreviewMethod')
      expect(all(after, '//eb:MessageProperties/eb:Property').size).to eq(2)
      expect(second.preview_link.address).to start_with("#{preview}&returnurl=")
    end
  end
end
