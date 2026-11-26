require 'rails_helper'

RSpec.describe EvidenceProvision::RejectUnaddressableRequest do
  subject(:reject) { described_class.call(message:, exchange: nil, audit_trail: AuditTrail.new) }

  let(:complete) { EbmsIdentity.new(id: '0671516647', type_id: 'urn:cef.eu:names:identifier:EAS:0208') }

  def message_with(original_sender: complete, final_recipient: complete)
    instance_double(RetrievedMessageParser, original_sender:, final_recipient:)
  end

  context 'when both corners carry a value and a type' do
    let(:message) { message_with }

    it 'lets the request through, and journals nothing' do
      expect(reject).to be_success
      expect(AuditEvent.count).to eq(0)
    end
  end

  {
    'the original sender is absent' => [{ original_sender: EbmsIdentity.new }, 'originalSender', 'value'],
    'the original sender is blank' => [{ original_sender: EbmsIdentity.new(id: ' ', type_id: 'urn:x') },
                                       'originalSender', 'value'],
    'the original sender has no type' => [{ original_sender: EbmsIdentity.new(id: '0671516647') },
                                          'originalSender', 'type'],
    'the final recipient is absent' => [{ final_recipient: EbmsIdentity.new }, 'finalRecipient', 'value'],
    'the final recipient has no type' => [{ final_recipient: EbmsIdentity.new(id: '13000247900016') },
                                          'finalRecipient', 'type'],
    'the final recipient has an empty type' => [{ final_recipient: EbmsIdentity.new(id: '13000247900016', type_id: '') },
                                                'finalRecipient', 'type'],
  }.each do |situation, (corners, property, part)|
    context "when #{situation}" do
      let(:message) { message_with(**corners) }
      let(:reason) do
        I18n.t("interactors.evidence_provision.reject_unaddressable_request.missing_#{part}", property:)
      end

      it 'refuses the request, naming the property and what it lacks' do
        expect { reject }.to raise_error(UnreadableMessageError, reason)
      end

      it 'journals the refusal' do
        suppress(UnreadableMessageError) { reject }

        expect(AuditEvent.sole).to have_attributes(event_type: 'request_refused', detail: reason)
      end
    end
  end

  it 'refuses on the original sender first when both corners lack their value' do
    message = message_with(original_sender: EbmsIdentity.new, final_recipient: EbmsIdentity.new)

    expect { described_class.call(message:, exchange: nil, audit_trail: AuditTrail.new) }
      .to raise_error(UnreadableMessageError, /originalSender/)
  end
end
