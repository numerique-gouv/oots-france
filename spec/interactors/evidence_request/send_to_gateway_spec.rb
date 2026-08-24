require 'rails_helper'

RSpec.describe EvidenceRequest::SendToGateway do
  include OotsNamespaces

  subject(:send_to_gateway) { described_class.call(gateway:, exchange:, **fetch_arguments) }

  let(:gateway) { gateway_accepting_submissions }
  let(:exchange) { create(:exchange) }

  let(:fetch_arguments) do
    {
      requester: build(:evidence_requester),
      provider: build(:evidence_provider, identifier: build(:ebms_identity, id: 'DE73524311')),
      recipient: build(:access_point, id: 'AP_DE_01'),
      beneficiary: build(:natural_person, eidas_identifier: 'FR/DE/123123123'),
      evidence_type: build(:evidence_type),
      requirement: build(:requirement),
      data_service: build(:data_service),
      procedure_code: ProcedureCode::STUDENT_GRANT,
      preview_possible: false,
      uuid: Oots::SequentialUuids.new,
      audit_trail: AuditTrail.new,
    }
  end

  def submitted = Nokogiri::XML(gateway_envelope)

  # Chapter 4.4 keeps the two apart, and so does the header: the conversation
  # in `eb:CollaborationInfo`, where `R-EDM-ebMS-017` puts it, and the exchange
  # in the `ExchangeId` property named by `R-EDM-ebMS-019`. Both are the ones
  # the row was opened under, so the answer can find it.
  it 'submits a request, under the exchange and the conversation the answer will name' do
    send_to_gateway

    expect(action_of(submitted)).to eq(EbmsAction::EXECUTE_QUERY_REQUEST)
    expect(conversation_of(submitted)).to eq(exchange.conversation_id)
    expect(property_of(submitted, 'ExchangeId')).to eq(exchange.exchange_id)
  end

  # Chapter 4.4 correlates a response to its request by this identifier, and
  # kept nowhere it could never be compared: `SettleExchange` reads it back
  # to tell our answer from a message that is not ours.
  it 'records on the exchange the request identifier it sent' do
    send_to_gateway

    expect(exchange.reload.request_id).to eq(request_id_of(submitted))
  end

  # Before the submission, and not after: the answer can come back before
  # `submit` has returned, and a response arriving first would find nothing to
  # compare itself against.
  it 'records it before handing anything to the gateway' do
    allow(gateway).to receive(:submit) do
      expect(exchange.reload.request_id).to be_present
      instance_double(SubmittedMessageParser, message_id: 'message-passerelle')
    end

    send_to_gateway
  end

  # The submission is addressed to the party the PMode declares, while the
  # corners of the four-corner model are the requester and the provider
  # themselves. Confusing the two produces a message the gateway routes nowhere.
  it 'addresses it to the access point, on behalf of the requester' do
    send_to_gateway

    expect(recipient_of(submitted)).to eq('AP_DE_01')
    expect(property_of(submitted, 'finalRecipient')).to eq('DE73524311')
    expect(property_of(submitted, 'originalSender')).to eq(fetch_arguments[:requester].id)
  end

  # The identifier the gateway gives the message it accepted is the only route
  # back to the `ds:SignedInfo` it signed, which is how chapter 4.8 reconstitutes
  # non-repudiation: dropping it would leave the log unable to prove anything.
  it 'journals the request, under the name the gateway gave it' do
    send_to_gateway

    expect(AuditEvent.last).to have_attributes(
      event_type: 'request_sent',
      exchange_id: exchange.exchange_id,
      message_id: 'message-passerelle',
      request_id: start_with('urn:uuid:'),
      requesting_authority_id: '00000000000002',
      providing_authority_id: 'DE73524311',
      country_code: exchange.country_code,
      evidence_subject_key: 'dupont|sophie|1965-11-25',
    )
  end

  it 'records that the exchange is now waiting on the correspondent' do
    send_to_gateway

    expect(exchange.reload).to have_attributes(status: 'sent')
  end

  # Left in `pending`, the exchange would stay open on an answer nobody is
  # coming back with: nothing was sent, so nothing will ever settle it.
  describe 'a gateway that refuses the submission' do
    before { allow(gateway).to receive(:submit).and_raise(Faraday::ConnectionFailed, 'connexion refusée') }

    it 'settles the exchange as failed rather than leaving it hanging' do
      send_to_gateway

      expect(exchange.reload).to have_attributes(status: 'failed', error_description: /connexion refusée/)
    end

    # 502 and not 422: the caller is told the failure is upstream of them,
    # which is what the key carries.
    it 'reports it as a gateway refusal' do
      expect(send_to_gateway).to be_failure
      expect(send_to_gateway.error).to include(key: :gateway_refused, errors: ['connexion refusée'])
    end
  end

  # The gateway can answer 200 with a body we cannot read. From the caller's
  # point of view that is the same problem — the gateway — and not a fault of
  # theirs, so it must not escape as an unhandled error.
  describe 'a gateway answering something unreadable' do
    before { allow(gateway).to receive(:submit).and_raise(UnreadableMessageError, 'Enveloppe SOAP illisible.') }

    it 'reports it as a gateway refusal too, rather than raising' do
      expect(send_to_gateway).to be_failure
      expect(send_to_gateway.error).to include(key: :gateway_refused)
      expect(exchange.reload).to have_attributes(status: 'failed')
    end
  end

  def gateway_envelope
    expect(gateway).to have_received(:submit) { |envelope| return envelope }
  end

  # Read with the parsers' own reader, not a copy of it: one prefix spelled
  # differently here from there is a spec that passes against a message the
  # application cannot read.
  def action_of(document) = text_at(document, '//eb:Action')

  def conversation_of(document) = text_at(document, '//eb:ConversationId')

  def recipient_of(document) = text_at(document, '//eb:To/eb:PartyId')

  def property_of(document, name) = text_at(document, "//eb:Property[@name=\"#{name}\"]")

  def request_id_of(document)
    at(document, '//payload/value')
      .then { |value| Nokogiri::XML(Base64.decode64(value.text)) }
      .then { |body| attribute(body.root, 'id') }
  end
end
