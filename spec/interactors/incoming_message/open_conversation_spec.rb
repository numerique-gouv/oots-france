require 'rails_helper'

RSpec.describe IncomingMessage::OpenConversation do
  subject(:open_conversation) { described_class.call(message:) }

  let(:body) { instance_double(EvidenceRequestParser, procedure_code: '00', requester:) }
  let(:requester) { EvidenceRequester.new(id: '00000000000009', type_id: '0002') }

  context 'when a member state asks France' do
    let(:message) do
      instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_REQUEST,
        conversation_id: 'venue-d-ailleurs', body:)
    end

    # Answering leaves a row where asking does: the listing that used to show
    # only what France requested now shows both halves of the four-corner model.
    it 'opens an exchange of its own' do
      open_conversation

      expect(Conversation.sole).to have_attributes(
        conversation_id: 'venue-d-ailleurs', incoming: true,
        procedure_code: '00', evidence_requester_id: '00000000000009', status: 'pending',
      )
    end

    # The fallback sweep can bring back a message the push notification already
    # delivered, and the unique index would make the second arrival raise.
    it 'recognises an arrival it has already opened' do
      open_conversation

      expect { described_class.call(message:) }.not_to change(Conversation, :count)
    end

    # L'identifiant vient de l'en-tête du correspondant, à qui la France a fait
    # connaître les siens en requêtant : adopter l'échange qu'il désigne
    # laisserait la réponse française régler la requête d'un autre.
    it 'refuses to adopt an exchange France opened itself' do
      create(:conversation, conversation_id: 'venue-d-ailleurs', incoming: false)

      expect { open_conversation }.to raise_error(ActiveRecord::RecordInvalid)
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
