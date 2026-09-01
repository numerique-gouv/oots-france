require 'rails_helper'

RSpec.describe EvidenceRequest::CheckSpecification do
  subject(:check) { described_class.call(exchange:, recipient:) }

  let(:exchange) { create(:exchange) }

  context 'when the access point announces the version the request carries' do
    let(:recipient) { build(:access_point, :foreign) }

    it 'goes on, leaving the exchange untouched' do
      expect(check).to be_success
      expect(exchange.reload.status).to eq('pending')
      expect(exchange.error_description).to be_nil
    end
  end

  context 'when the access point announces another version' do
    let(:recipient) { build(:access_point, :foreign, :outdated) }

    it 'settles the exchange as failed, naming both versions and the access point' do
      expect(check).to be_failure
      expect(check.error[:key]).to eq(:unsupported_specification)

      expect(exchange.reload.status).to eq('failed')
      expect(exchange.error_description).to include('AP_DE_01', 'oots-edm:v1.2', EdmSpecification::IDENTIFIER)
    end

    # No EDM code, for the reason `SendToGateway` gives its own pre-submission
    # refusals: the eight exceptions of chapter 4.5.3 all describe a server
    # handling a request, and none a sender that never submitted.
    it 'imputes no EDM exception to a correspondent no message reached' do
      check

      expect(exchange.reload.edm_error_code).to be_nil
    end
  end

  context 'when the access point announces several versions, none of them ours' do
    let(:recipient) { build(:access_point, :foreign, conforms_to: ['oots-edm:v1.0', 'oots-edm:v1.2']) }

    it 'refuses, naming all of them' do
      expect(check).to be_failure
      expect(exchange.reload.error_description).to include('oots-edm:v1.0', 'oots-edm:v1.2')
    end
  end

  context 'when the access point announces no version at all' do
    let(:recipient) { build(:access_point, :foreign, conforms_to: []) }

    it 'goes on: the directory said nothing, and the query already filtered on the version' do
      expect(check).to be_success
      expect(exchange.reload.status).to eq('pending')
    end
  end
end
