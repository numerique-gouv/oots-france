require 'rails_helper'

RSpec.describe IncomingMessage::OpenExchange do
  # Chosen by the correspondent, and kept apart here as the header keeps them
  # apart: chapter 4.4 lets one conversation cover several exchanges.
  FOREIGN_EXCHANGE = '88888888-8888-8888-8888-888888888888'.freeze
  FOREIGN_CONVERSATION = '5fe50e16-d6b8-4005-b5ec-0ab097f34448'.freeze

  subject(:open_exchange) { described_class.call(message:) }

  let(:body) { instance_double(EvidenceRequestParser, procedure_code: '00', requester:) }
  let(:requester) { EvidenceRequester.new(id: '00000000000009', type_id: '0002', address: Address.new(country: 'FI')) }

  # The stamp the sending gateway put on the message — see `Exchange` for why a
  # received exchange's timeout is counted from it rather than from reception.
  STAMPED_AT = Time.zone.parse('2026-09-01T09:15:00Z').freeze

  context 'when a member state asks France' do
    let(:message) do
      instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_REQUEST,
        exchange_id: FOREIGN_EXCHANGE, conversation_id: FOREIGN_CONVERSATION,
        sent_at: STAMPED_AT, body:)
    end

    # Answering leaves a row where asking does, so the listing carries both
    # halves of the four-corner model: what France asks, and what it is asked.
    it 'opens an exchange of its own' do
      open_exchange

      expect(Exchange.sole).to have_attributes(
        exchange_id: FOREIGN_EXCHANGE, conversation_id: FOREIGN_CONVERSATION, incoming: true,
        procedure_code: '00', evidence_requester_id: '00000000000009', status: 'pending',
        # The exchange keeps it because nothing can read it back:
        # `retention_downloaded="0"` has the gateway erase the message the
        # instant `retrieveMessage` returns.
        ebms_sent_at: STAMPED_AT,
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
      expect(Exchange.sole).to have_attributes(incoming: false, country_code: 'FI', ebms_sent_at: nil)
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

    # A header whose timestamp is malformed opens the exchange without a clock
    # rather than keeping the row from being written at all: `Exchange.expired`
    # then leaves it alone, which is what an exchange with nothing to count from
    # deserves.
    context 'when the header carries no readable timestamp' do
      before { allow(message).to receive(:sent_at).and_raise(UnreadableMessageError, 'illisible') }

      # Field by field, as the five others are: only the stamp is lost, the body
      # having been perfectly readable.
      it 'opens it all the same, with no stamp to count a timeout from' do
        open_exchange

        expect(Exchange.sole).to have_attributes(exchange_id: FOREIGN_EXCHANGE, incoming: true,
          ebms_sent_at: nil, procedure_code: '00', country_code: 'FI',
          evidence_requester_id: '00000000000009')
      end
    end
  end

  # `R-EDM-ebMS-019` makes the `ExchangeId` property mandatory, and the ebMS3
  # envelope the `eb:ConversationId` element, so a request carrying neither
  # names nothing to open a row under. It must be
  # refused where `IncomingMessage::Process` can give up on it — the arrival is
  # journalled by then — and never let the row's own validation raise where
  # nothing catches it: `retrieveMessage` has already erased the message, so an
  # uncaught failure loses it for good.
  context 'when the header names no exchange' do
    it 'refuses a request carrying no exchange identifier' do
      message = instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_REQUEST,
        exchange_id: nil, conversation_id: FOREIGN_CONVERSATION, body:)

      expect { described_class.call(message:, audit_trail: AuditTrail.new) }
        .to raise_error(UnreadableMessageError)
    end

    it 'refuses a request carrying no conversation identifier' do
      message = instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_REQUEST,
        exchange_id: FOREIGN_EXCHANGE, conversation_id: nil, body:)

      expect { described_class.call(message:, audit_trail: AuditTrail.new) }
        .to raise_error(UnreadableMessageError)
    end

    it 'opens nothing' do
      message = instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_REQUEST,
        exchange_id: nil, conversation_id: nil, body:)

      suppress(UnreadableMessageError) { described_class.call(message:, audit_trail: AuditTrail.new) }

      expect(Exchange.count).to eq(0)
    end

    # Nothing goes back to the correspondent and no exchange row carries the
    # decision, so the journal is the only place it can be read afterwards —
    # `docs/journal_des_echanges.md` asks a refusal whose reason is known to
    # record it.
    it 'journals why nothing followed the arrival' do
      message = instance_double(RetrievedMessageParser, action: EbmsAction::EXECUTE_QUERY_REQUEST,
        exchange_id: nil, conversation_id: FOREIGN_CONVERSATION, body:)

      suppress(UnreadableMessageError) { described_class.call(message:, audit_trail: AuditTrail.new) }

      expect(AuditEvent.sole).to have_attributes(
        event_type: 'request_refused',
        evidence_requester_id: '00000000000009',
        procedure_code: '00',
        country_code: 'FI',
        detail: I18n.t('interactors.incoming_message.open_exchange.unidentified'),
      )
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
