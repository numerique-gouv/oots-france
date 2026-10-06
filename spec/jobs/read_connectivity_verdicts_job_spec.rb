require 'rails_helper'

RSpec.describe ReadConnectivityVerdictsJob do
  let(:gateway) { instance_double(DomibusClient) }

  before do
    allow(DomibusClient).to receive(:new).and_return(gateway)
    allow(gateway).to receive(:message_status).and_return(MessageStatusParser.new(built_envelope('domibus/statutEnFile')))
  end

  it 'reads the verdict of every submitted test' do
    test = create(:connectivity_test, :submitted)
    allow(gateway).to receive(:message_status)
      .and_return(MessageStatusParser.new(built_envelope('domibus/statutAcquitte')))

    described_class.perform_now

    expect(test.reload.outcome).to eq('acknowledged')
  end

  it 'asks nothing of a test not yet submitted' do
    create(:connectivity_test)

    described_class.perform_now

    expect(gateway).not_to have_received(:message_status)
  end

  # RG4 of OOTS-252: no single attempt lasts a quarter of an hour.
  it 'closes without a verdict what stayed pending fifteen minutes, submitted or not, and logs it' do
    allow(Rails.logger).to receive(:warn)
    unsubmitted = create(:connectivity_test, requested_at: 16.minutes.ago)
    submitted = create(:connectivity_test, :submitted, requested_at: 16.minutes.ago)
    recent = create(:connectivity_test, :submitted)

    described_class.perform_now

    expect([unsubmitted, submitted, recent].map { |test| test.reload.outcome }).to eq(%w[no_verdict no_verdict pending])
    expect(Rails.logger).to have_received(:warn).with(include(unsubmitted.party_name))
  end

  it 'lets no row carry the others away' do
    allow(Rails.logger).to receive(:error)
    failing, passing = create_list(:connectivity_test, 2, :submitted)
    allow(gateway).to receive(:message_status).with(failing.message_id, role: 'SENDING').and_raise(ArgumentError)
    allow(gateway).to receive(:message_status).with(passing.message_id, role: 'SENDING')
      .and_return(MessageStatusParser.new(built_envelope('domibus/statutAcquitte')))

    described_class.perform_now

    expect(passing.reload.outcome).to eq('acknowledged')
    expect(Rails.logger).to have_received(:error).with(include(failing.party_name))
  end

  # RG7 of OOTS-252: a connectivity test is not an exchange.
  it 'touches neither the exchanges nor the exchange log' do
    create(:connectivity_test, :submitted)
    allow(gateway).to receive(:message_status)
      .and_return(MessageStatusParser.new(built_envelope('domibus/statutAcquitte')))

    expect { described_class.perform_now }.not_to(change { [Exchange.count, AuditEvent.count] })
  end
end
