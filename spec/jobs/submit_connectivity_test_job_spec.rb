require 'rails_helper'

RSpec.describe SubmitConnectivityTestJob do
  let(:gateway) { gateway_accepting_submissions(message_id: 'test@domibus.eu') }

  before { allow(DomibusClient).to receive(:new).and_return(gateway) }

  it 'submits the test it was enqueued for' do
    test = create(:connectivity_test)

    described_class.perform_now(test.id, test.requested_at)

    expect(test.reload.message_id).to eq('test@domibus.eu')
  end

  it 'follows the test it submitted' do
    test = create(:connectivity_test)

    expect { described_class.perform_now(test.id, test.requested_at) }
      .to have_enqueued_job(FollowConnectivityTestJob).with(test.id)
  end

  it 'submits nothing for a test asked again since' do
    test = create(:connectivity_test)

    described_class.perform_now(test.id, test.requested_at - 1.hour)

    expect(gateway).not_to have_received(:submit)
  end
end
