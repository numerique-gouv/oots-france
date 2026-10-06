require 'rails_helper'

RSpec.describe ConnectivityTesting::ReadVerdict do
  subject(:read) { described_class.call(test:, gateway:) }

  let(:test) { create(:connectivity_test, :submitted) }
  let(:status) { 'statutAcquitte' }
  let(:errors) { 'erreursRemise' }
  let(:gateway) { instance_double(DomibusClient) }

  before do
    allow(gateway).to receive(:message_status)
      .with(test.message_id, role: 'SENDING').and_return(MessageStatusParser.new(built_envelope("domibus/#{status}")))
    allow(gateway).to receive(:message_errors)
      .with(test.message_id).and_return(MessageErrorsParser.new(built_envelope("domibus/#{errors}")))
  end

  it 'reads an acknowledgement' do
    read

    expect(test.reload).to have_attributes(outcome: 'acknowledged', verdict_read_at: be_present)
  end

  context 'when acknowledged with a warning' do
    let(:status) { 'statutAcquitteAvecAvertissement' }

    it('reads an acknowledgement') { expect { read }.to change { test.reload.outcome }.to('acknowledged') }
  end

  context 'when the gateway gave up' do
    let(:status) { 'statutEchec' }

    it 'reads a refusal for the configuration of the access point, by the last error' do
      read

      expect(test.reload).to have_attributes(outcome: 'refused_for_configuration', error_code: 'EBMS:0003',
        error_detail: 'No matching party found')
    end

    # The refusal the correspondent returns in a SOAP fault, recorded under
    # `RECEIVING` beside the gateway's own `EBMS:0005`.
    context 'when the access point refused it in a fault' do
      let(:errors) { 'erreursRemise.refusDistant' }

      it 'reads the refusal for its configuration the correspondent signalled' do
        read

        expect(test.reload).to have_attributes(outcome: 'refused_for_configuration', error_code: 'EBMS:0003',
          error_detail: start_with('Sender party could not be found'))
      end
    end

    # France's own access point: the gateway holds the identifier twice, and
    # refuses the form without a role.
    context 'when the gateway refuses to read the errors without a role' do
      before do
        allow(gateway).to receive(:message_errors).with(test.message_id).and_raise(Faraday::ServerError, 'Duplicate')
        allow(gateway).to receive(:message_errors).with(test.message_id, role: 'SENDING')
          .and_return(MessageErrorsParser.new(built_envelope('domibus/erreursRemise.connexion')))
      end

      it 'reads them as the side that sent' do
        read

        expect(test.reload).to have_attributes(outcome: 'failed', error_code: 'EBMS:0005')
      end
    end

    context 'when the access point could not be reached' do
      let(:errors) { 'erreursRemise.connexion' }

      it 'reads a failure with its code' do
        read

        expect(test.reload).to have_attributes(outcome: 'failed', error_code: 'EBMS:0005',
          error_detail: 'Connection refused')
      end
    end

    context 'without any error recorded' do
      let(:errors) { 'erreursRemise.vide' }

      it('reads a failure without a code, and logs the message') do
        allow(Rails.logger).to receive(:warn)

        read

        expect(test.reload).to have_attributes(outcome: 'failed', error_code: nil)
        expect(Rails.logger).to have_received(:warn).with(include(test.message_id))
      end
    end
  end

  context 'when the gateway no longer knows the message' do
    let(:status) { 'statutInconnu' }

    it 'closes the test without a verdict, and logs the message' do
      allow(Rails.logger).to receive(:warn)

      read

      expect(test.reload.outcome).to eq('no_verdict')
      expect(Rails.logger).to have_received(:warn).with(include(test.message_id))
    end
  end

  context 'when the message is still on its way' do
    let(:status) { 'statutEnFile' }

    it('leaves the test pending') { expect { read }.not_to(change { test.reload.attributes }) }
  end

  # The page asked the party again while the gateway was answering about the
  # previous message: that answer must not close the new request.
  context 'when the test was asked again while its verdict was being read' do
    before do
      allow(gateway).to receive(:message_status) do
        ConnectivityTest.find(test.id).update!(outcome: 'pending', message_id: 'nouveau@domibus.eu',
          requested_at: Time.current)
        MessageStatusParser.new(built_envelope('domibus/statutAcquitte'))
      end
    end

    it 'leaves the new request pending' do
      read

      expect(ConnectivityTest.find(test.id)).to have_attributes(outcome: 'pending', message_id: 'nouveau@domibus.eu')
    end
  end

  context 'when the gateway cannot be read' do
    before { allow(gateway).to receive(:message_status).and_raise(Faraday::ServerError, 'Fault') }

    it 'leaves the test pending, and logs it' do
      allow(Rails.logger).to receive(:error)

      expect { read }.not_to(change { test.reload.attributes })
      expect(Rails.logger).to have_received(:error).with(include(test.message_id))
    end
  end
end
