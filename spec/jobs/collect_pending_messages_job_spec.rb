require 'rails_helper'

RSpec.describe CollectPendingMessagesJob do
  # The job is the schedule and nothing else: what it does is
  # `IncomingMessage::CollectPending`'s, and that step's own spec judges it.
  it 'delegates the sweep to the step that performs it' do
    allow(IncomingMessage::CollectPending).to receive(:call)

    described_class.perform_now

    expect(IncomingMessage::CollectPending).to have_received(:call)
  end
end
