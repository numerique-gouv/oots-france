require 'rails_helper'

RSpec.describe IncomingMessage::CollectPending do
  subject(:collect) { described_class.call(gateway:) }

  let(:gateway) { instance_double(DomibusClient, pending_messages: pending) }
  let(:pending) { instance_double(PendingMessagesParser, message_ids: %w[un-message un-autre]) }

  it 'hands each message the gateway still holds to the job that processes it' do
    expect { collect }.to have_enqueued_job(ProcessIncomingMessageJob).with('un-message')
      .and have_enqueued_job(ProcessIncomingMessageJob).with('un-autre')
  end

  describe 'a gateway holding nothing' do
    let(:pending) { instance_double(PendingMessagesParser, message_ids: []) }

    it 'enqueues nothing' do
      expect { collect }.not_to have_enqueued_job(ProcessIncomingMessageJob)
    end
  end

  # The form every other step uses for its infrastructure: the scheduler passes
  # nothing, and the default is the only path in production.
  it 'gives itself the gateway when its caller names none' do
    allow(DomibusClient).to receive(:new).and_return(gateway)

    expect { described_class.call }.to have_enqueued_job(ProcessIncomingMessageJob).with('un-message')
  end
end
