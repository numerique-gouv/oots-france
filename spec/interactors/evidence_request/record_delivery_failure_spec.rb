require 'rails_helper'

RSpec.describe EvidenceRequest::RecordDeliveryFailure do
  subject(:record) { described_class.call(message_id:, status:, gateway:) }

  let(:message_id) { '8a1c0e3f-7b2d-4c6e-9f10-2d3e4f5a6b7c@oots.eu' }
  let(:status) { 'WAITING_FOR_RETRY' }
  let(:exchange) { create(:exchange, :sent, request_message_id: message_id) }
  let(:latest) { DeliveryError.new(code: 'EBMS_0003', detail: 'No matching party found') }
  let(:gateway) do
    instance_double(DomibusClient, message_errors: instance_double(MessageErrorsParser, latest:))
  end

  before { exchange }

  describe 'an attempt the gateway will retry' do
    it 'closes the exchange at once on a refusal of the access point' do
      record

      expect(exchange.reload).to have_attributes(
        status: 'failed', edm_error_code: nil,
        error_description: "Le point d'accès du correspondant a refusé la requête (EBMS:0003 : No matching party found).",
      )
      expect(exchange).to be_presumed
    end

    context 'when the access point could not be reached' do
      let(:latest) { DeliveryError.new(code: 'EBMS_0005', detail: 'Connection refused') }

      it 'leaves the exchange to the retries' do
        expect { record }.not_to(change { exchange.reload.attributes })
      end
    end

    context 'when the gateway cannot say why' do
      let(:gateway) { instance_double(DomibusClient) }

      before { allow(gateway).to receive(:message_errors).and_raise(Faraday::ServerError, 'Fault') }

      it 'leaves the exchange in progress, and says so' do
        allow(Rails.logger).to receive(:error)

        record

        expect(exchange.reload.status).to eq('sent')
        expect(Rails.logger).to have_received(:error).with(include(message_id))
      end
    end

    it 'changes nothing on an exchange it already closed, and asks nothing' do
      record
      before = exchange.reload.attributes

      described_class.call(message_id:, status:, gateway:)

      expect(exchange.reload.attributes).to eq(before)
      expect(gateway).to have_received(:message_errors).once
    end

    # The sweep's guess waits for the verdict.
    it 'leaves alone an exchange the sweep presumed expired' do
      exchange.expire!

      record

      expect(exchange.reload).to have_attributes(edm_error_code: 'EDM:ERR:0005')
      expect(exchange).to be_presumed
      expect(gateway).not_to have_received(:message_errors)
    end
  end

  describe 'a gateway that gave up' do
    let(:status) { 'SEND_FAILURE' }

    it 'confirms its own presumption' do
      exchange.refused_by_access_point!(latest)

      record

      expect(exchange.reload).to have_attributes(
        status: 'failed', presumed_at: nil,
        error_description: 'La passerelle a renoncé à remettre la requête (EBMS:0003 : No matching party found).',
      )
    end

    it 'replaces the presumption of the sweep' do
      exchange.expire!

      record

      expect(exchange.reload).to have_attributes(status: 'failed', edm_error_code: nil, presumed_at: nil)
    end

    context 'when the access point could not be reached' do
      let(:latest) { DeliveryError.new(code: 'EBMS_0005', detail: 'Connection refused') }

      it 'closes an exchange still in progress all the same' do
        record

        expect(exchange.reload).to have_attributes(status: 'failed', edm_error_code: nil,
          error_description: 'La passerelle a renoncé à remettre la requête (EBMS:0005 : Connection refused).')
      end
    end

    context 'when the gateway cannot say why' do
      let(:gateway) { instance_double(DomibusClient) }

      before { allow(gateway).to receive(:message_errors).and_raise(Faraday::ServerError, 'Fault') }

      it 'says the gateway gave up, and nothing more' do
        record

        expect(exchange.reload.error_description).to eq('La passerelle a renoncé à remettre la requête.')
      end
    end
  end

  %w[WAITING_FOR_RETRY SEND_FAILURE].each do |notified|
    context "when #{notified} arrives on an exchange settled otherwise" do
      let(:status) { notified }

      it 'leaves it settled, asks nothing, and says so' do
        exchange.delivered!
        allow(Rails.logger).to receive(:warn)

        record

        expect(exchange.reload.status).to eq('delivered')
        expect(gateway).not_to have_received(:message_errors)
        expect(Rails.logger).to have_received(:warn).with(include(exchange.exchange_id))
      end
    end

    # A notification repeated after the verdict: the fact stands.
    context "when #{notified} arrives once the gateway has given up" do
      let(:status) { notified }

      it 'keeps the verdict, asks nothing, and says so' do
        exchange.undelivered!(latest)
        before = exchange.reload.attributes
        allow(Rails.logger).to receive(:warn)

        record

        expect(exchange.reload.attributes).to eq(before)
        expect(gateway).not_to have_received(:message_errors)
        expect(Rails.logger).to have_received(:warn).with(include(exchange.exchange_id))
      end
    end
  end

  # Every exchange France answers, and every one not yet submitted, carries no
  # request identifier: a notification naming none must not reach them.
  it 'touches no exchange on a notification naming no message' do
    incoming = create(:exchange, :sent, request_message_id: nil)
    allow(Rails.logger).to receive(:warn)

    described_class.call(message_id: nil, status: 'SEND_FAILURE', gateway:)

    expect(incoming.reload.status).to eq('sent')
    expect(gateway).not_to have_received(:message_errors)
  end

  it 'says it knows no request under an identifier nobody submitted' do
    allow(Rails.logger).to receive(:warn)

    described_class.call(message_id: 'inconnu@oots.eu', status:, gateway:)

    expect(gateway).not_to have_received(:message_errors)
    expect(Rails.logger).to have_received(:warn).with(include('inconnu@oots.eu'))
  end
end
