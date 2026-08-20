require 'rails_helper'

RSpec.describe IncomingMessage::OpenConversation do
  subject(:open_conversation) { described_class.call(message:) }

  let(:body) { instance_double(EvidenceRequestParser, procedure_code: '00', requester:) }
  let(:requester) { EvidenceRequester.new(id: '00000000000009', type_id: '0002', address: Address.new(country: 'FI')) }

  context 'when a member state asks France' do
    let(:message) do
      instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_REQUEST,
        conversation_id: 'venue-d-ailleurs', body:)
    end

    # Answering leaves a row where asking does, so the listing carries both
    # halves of the four-corner model: what France asks, and what it is asked.
    it 'opens an exchange of its own' do
      open_conversation

      expect(Conversation.sole).to have_attributes(
        conversation_id: 'venue-d-ailleurs', incoming: true,
        procedure_code: '00', evidence_requester_id: '00000000000009', status: 'pending',
        # `R-EDM-REQ-C073` puts it on the agent classified `ER`: the country
        # that asks, and never France's own.
        country_code: 'FI',
      )
    end

    # The fallback sweep can bring back a message the push notification already
    # delivered, and the unique index would make the second arrival raise.
    it 'recognises an arrival it has already opened' do
      open_conversation

      expect { described_class.call(message:) }.not_to change(Conversation, :count)
    end

    # The end-to-end scenario loops through a single gateway: France holds both
    # its roles there, and one identifier legitimately names both sides.
    it 'adopts without changing it an exchange that bears the same identifier' do
      create(:conversation, conversation_id: 'venue-d-ailleurs', incoming: false, country_code: 'FI')

      expect { open_conversation }.not_to change(Conversation, :count)
      expect(Conversation.sole).to have_attributes(incoming: false, country_code: 'FI')
    end

    # The exchange an auditor most needs to find is the one nobody could honour.
    context 'when the body cannot be read' do
      before { allow(body).to receive(:procedure_code).and_raise(UnreadableMessageError, 'illisible') }

      it 'opens it all the same, with what could be read missing' do
        open_conversation

        expect(Conversation.sole).to have_attributes(conversation_id: 'venue-d-ailleurs', incoming: true,
          procedure_code: nil)
      end
    end
  end

  # A response or an error names an exchange France opened itself.
  context 'when a correspondent answers France' do
    let(:message) do
      instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_RESPONSE,
        conversation_id: 'la-notre', body:)
    end

    it 'opens nothing' do
      expect { open_conversation }.not_to change(Conversation, :count)
    end
  end
end
