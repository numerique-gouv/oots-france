require 'rails_helper'

RSpec.describe FollowConnectivityTestJob do
  let(:gateway) { instance_double(DomibusClient) }
  let(:status) { 'statutEnFile' }

  before do
    allow(DomibusClient).to receive(:new).and_return(gateway)
    allow(gateway).to receive(:message_status)
      .and_return(MessageStatusParser.new(built_envelope("domibus/#{status}")))
  end

  context 'when the gateway has settled the test' do
    let(:status) { 'statutAcquitte' }

    it 'reads the verdict, and asks no more' do
      test = create(:connectivity_test, :submitted)

      expect { described_class.perform_now(test.id) }.not_to have_enqueued_job(described_class)
      expect(test.reload.outcome).to eq('acknowledged')
    end
  end

  it 'asks again a few seconds later while the test is pending' do
    test = create(:connectivity_test, :submitted, requested_at: 30.seconds.ago)

    expect { described_class.perform_now(test.id) }.to have_enqueued_job(described_class).with(test.id)
  end

  it 'leaves a test pending past two minutes to the sweep' do
    test = create(:connectivity_test, :submitted, requested_at: 3.minutes.ago)

    expect { described_class.perform_now(test.id) }.not_to have_enqueued_job(described_class)
  end
end
