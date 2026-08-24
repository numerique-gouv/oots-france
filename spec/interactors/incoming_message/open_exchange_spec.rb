require 'rails_helper'

RSpec.describe IncomingMessage::OpenExchange do
  # Chosen by the correspondent, and kept apart here as the header keeps them
  # apart: chapter 4.4 lets one conversation cover several exchanges.
  FOREIGN_EXCHANGE = '88888888-8888-8888-8888-888888888888'.freeze
  FOREIGN_CONVERSATION = '5fe50e16-d6b8-4005-b5ec-0ab097f34448'.freeze

  subject(:open_exchange) { described_class.call(message:) }

  let(:body) { instance_double(EvidenceRequestParser, procedure_code: '00', requester:) }
  let(:requester) { EvidenceRequester.new(id: '00000000000009', type_id: '0002', address: Address.new(country: 'FI')) }

  context 'when a member state asks France' do
    let(:message) do
      instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_REQUEST,
        exchange_id: FOREIGN_EXCHANGE, conversation_id: FOREIGN_CONVERSATION, body:)
    end

    # Answering leaves a row where asking does, so the listing carries both
    # halves of the four-corner model: what France asks, and what it is asked.
    it 'opens an exchange of its own' do
      open_exchange

      expect(Exchange.sole).to have_attributes(
        exchange_id: FOREIGN_EXCHANGE, conversation_id: FOREIGN_CONVERSATION, incoming: true,
        procedure_code: '00', evidence_requester_id: '00000000000009', status: 'pending',
        # `R-EDM-REQ-C073` puts it on the agent classified `ER`: the country
        # that asks, and never France's own.
        country_code: 'FI',
      )
    end

    # The fallback sweep can bring back a message the push notification already
    # delivered, and the unique index would make the second arrival raise.
    it 'recognises an arrival it has already opened' do
      open_exchange

      expect { described_class.call(message:) }.not_to change(Exchange, :count)
    end

    # The end-to-end scenario loops through a single gateway: France holds both
    # its roles there, and one identifier legitimately names both sides.
    it 'adopts without changing it an exchange that bears the same identifier' do
      create(:exchange, exchange_id: FOREIGN_EXCHANGE, incoming: false, country_code: 'FI')

      expect { open_exchange }.not_to change(Exchange, :count)
      expect(Exchange.sole).to have_attributes(incoming: false, country_code: 'FI')
    end

    # The exchange an auditor most needs to find is the one nobody could honour.
    context 'when the body cannot be read' do
      before { allow(body).to receive(:procedure_code).and_raise(UnreadableMessageError, 'illisible') }

      it 'opens it all the same, with what could be read missing' do
        open_exchange

        expect(Exchange.sole).to have_attributes(exchange_id: FOREIGN_EXCHANGE, incoming: true,
          procedure_code: nil)
      end
    end
  end

  # A response or an error names an exchange France opened itself.
  context 'when a correspondent answers France' do
    let(:message) do
      instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_RESPONSE,
        exchange_id: 'la-notre', body:)
    end

    it 'opens nothing' do
      expect { open_exchange }.not_to change(Exchange, :count)
    end
  end
end
