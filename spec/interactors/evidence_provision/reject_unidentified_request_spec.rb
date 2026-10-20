require 'rails_helper'

RSpec.describe EvidenceProvision::RejectUnidentifiedRequest do
  subject(:reject) { described_class.call(message:, audit_trail: AuditTrail.new) }

  let(:body) { instance_double(EvidenceRequestParser, procedure_code: '00', requester:) }
  let(:requester) { EvidenceRequester.new(id: '00000000000009', type_id: '0002', address: Address.new(country: 'FI')) }

  context 'when the header names an exchange' do
    let(:message) { instance_double(RetrievedMessageParser, identified?: true, body:) }

    it 'lets the request through, and journals nothing' do
      expect(reject).to be_success
      expect(AuditEvent.count).to eq(0)
    end
  end

  # Refused where `IncomingMessage::Process` can give up on it, the arrival
  # being journalled by then: `retrieveMessage` has already erased the message,
  # so an uncaught failure would lose it for good.
  context 'when the header names no exchange' do
    let(:message) { instance_double(RetrievedMessageParser, identified?: false, body:) }

    it 'refuses the request' do
      expect { reject }.to raise_error(UnreadableMessageError,
        I18n.t('interactors.evidence_provision.reject_unidentified_request.unidentified'))
    end

    # Nothing goes back to the correspondent and no exchange row carries the
    # decision, so the journal is the only place it can be read afterwards.
    # CA7 of OOTS-254: no exchange, so no identifier on the line.
    it 'journals why nothing followed the arrival' do
      suppress(UnreadableMessageError) { reject }

      expect(AuditEvent.sole).to have_attributes(
        event_type: 'request_refused',
        exchange_id: nil,
        conversation_id: nil,
        evidence_requester_id: '00000000000009',
        procedure_code: '00',
        country_code: 'FI',
        detail: I18n.t('interactors.evidence_provision.reject_unidentified_request.unidentified'),
      )
    end

    it 'journals the refusal even when the body cannot be read' do
      allow(body).to receive(:procedure_code).and_raise(UnreadableMessageError, 'illisible')

      suppress(UnreadableMessageError) { reject }

      expect(AuditEvent.sole).to have_attributes(event_type: 'request_refused', procedure_code: nil,
        country_code: 'FI')
    end
  end
end
