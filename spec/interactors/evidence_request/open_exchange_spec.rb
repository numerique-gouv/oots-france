require 'rails_helper'

RSpec.describe EvidenceRequest::OpenExchange do
  subject(:open_exchange) { open_one }

  let(:requester) { build(:evidence_requester) }
  let(:uuid) { Oots::SequentialUuids.new }

  def open_one(conversation_id: nil)
    described_class.call(
      requester:, procedure_code: ProcedureCode::SYSTEM_CHECK, country_code: 'DE', uuid:, conversation_id:,
    )
  end

  # The identifier the message will travel under is the one the row carries:
  # that is the only thing tying a notification back to the exchange it answers.
  # Asserted against the literal the injected generator yields, because looking
  # the row up by its own attribute would hold true of any persisted row and
  # would say nothing about who minted the value.
  it 'records the exchange under the identifier the message will carry' do
    expect(open_exchange.exchange.exchange_id).to eq('1a2b3c4d-0000-4000-8000-000000000000')
  end

  # The requester is what the answer must be handed back to, and the worker that
  # receives it has nothing else to go on.
  it 'records which requester the answer goes back to' do
    expect(open_exchange.exchange)
      .to have_attributes(evidence_requester_id: requester.id, procedure_code: ProcedureCode::SYSTEM_CHECK,
        country_code: 'DE')
  end

  # `pending` and not merely unsettled: `sent` is unsettled too, and marking an
  # exchange sent before it has been submitted would pass any weaker assertion.
  # It is `SendToGateway` that moves it on, once the gateway has accepted it.
  it 'leaves it waiting for an answer' do
    expect(open_exchange.exchange).to have_attributes(status: 'pending', settled_at: nil)
  end

  # Chapter 4.4: a conversation « identifies a single uniquely authenticated
  # user » and « MAY span multiple actions, procedures, and evidence exchanges
  # within one user session », where an exchange is one round trip. So a portal
  # leading one user through two requests says so, and gets two exchanges under
  # one conversation.
  describe 'the conversation the exchange belongs to' do
    it 'gathers under one conversation the successive requests of one user' do
      first = open_one(conversation_id: '5fe50e16-d6b8-4005-b5ec-0ab097f34448').exchange
      second = open_one(conversation_id: '5fe50e16-d6b8-4005-b5ec-0ab097f34448').exchange

      expect(second.conversation_id).to eq(first.conversation_id)
      expect(second.exchange_id).not_to eq(first.exchange_id)
    end

    # « Assignment MAY be performed by the Procedure Portal or by the
    # Intermediary Platform »: this application is the latter, and a caller with
    # no session of its own leaves it to say so.
    it 'mints one when the caller names none' do
      expect(open_exchange.exchange.conversation_id).to be_present
    end

    # Two callers naming nothing are two users, and nothing may gather them.
    it 'gives a conversation of its own to each request that names none' do
      expect(open_one.exchange.conversation_id).not_to eq(open_one.exchange.conversation_id)
    end
  end
end
