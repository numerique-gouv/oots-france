require 'rails_helper'

RSpec.describe EvidenceRequest::OpenConversation do
  subject(:open_conversation) do
    described_class.call(
      requester:, procedure_code: ProcedureCode::SYSTEM_CHECK, country_code: 'DE', uuid: Oots::SequentialUuids.new,
    )
  end

  let(:requester) { build(:evidence_requester) }

  # The identifier the message will travel under is the one the row carries:
  # that is the only thing tying a notification back to the exchange it answers.
  # Asserted against the literal the injected generator yields, because looking
  # the row up by its own attribute would hold true of any persisted row and
  # would say nothing about who minted the value.
  it 'records the exchange under the identifier the message will carry' do
    expect(open_conversation.conversation.conversation_id).to eq('1a2b3c4d-0000-4000-8000-000000000000')
  end

  # The requester is what the answer must be handed back to, and the worker that
  # receives it has nothing else to go on.
  it 'records which requester the answer goes back to' do
    expect(open_conversation.conversation)
      .to have_attributes(evidence_requester_id: requester.id, procedure_code: ProcedureCode::SYSTEM_CHECK,
        country_code: 'DE')
  end

  # `pending` and not merely unsettled: `sent` is unsettled too, and marking an
  # exchange sent before it has been submitted would pass any weaker assertion.
  # It is `SendToGateway` that moves it on, once the gateway has accepted it.
  it 'leaves it waiting for an answer' do
    expect(open_conversation.conversation).to have_attributes(status: 'pending', settled_at: nil)
  end
end
