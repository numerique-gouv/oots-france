require 'rails_helper'

RSpec.describe EvidenceRequest::ChooseSpecification do
  subject(:choice) { described_class.call(exchange:, recipient:) }

  let(:exchange) { create(:exchange) }

  context 'when the access point announces both lines' do
    let(:recipient) { build(:access_point, :foreign, conforms_to: ['oots-edm:v1.2', 'oots-edm:v2.0']) }

    it 'writes 2.0 on the exchange and hands it to the rest of the chain' do
      expect(choice).to be_success
      expect(choice.specification).to eq(EdmSpecification::V2_0)
      expect(exchange.reload.specification).to eq(EdmSpecification::V2_0)
    end
  end

  context 'when the access point announces the 1.2 line alone' do
    let(:recipient) { build(:access_point, :foreign, :legacy_line) }

    it 'writes 1.2 on the exchange rather than refusing it' do
      expect(choice).to be_success
      expect(choice.specification).to eq(EdmSpecification::V1_2)
      expect(exchange.reload.specification).to eq(EdmSpecification::V1_2)
      expect(exchange.status).to eq('pending')
    end
  end

  context 'when the access point announces only versions France does not speak' do
    let(:recipient) { build(:access_point, :foreign, conforms_to: ['oots-edm:v1.0', 'oots-edm:v1.1']) }

    it 'settles the exchange as failed, naming what it announces and what France speaks' do
      expect(choice).to be_failure
      expect(choice.error[:key]).to eq(:unsupported_specification)

      expect(exchange.reload.status).to eq('failed')
      expect(exchange.error_description)
        .to include('AP_DE_01', 'oots-edm:v1.0', 'oots-edm:v1.1', 'oots-edm:v2.0', 'oots-edm:v1.2')
    end

    # No EDM code, for the reason `SendToGateway` gives its own pre-submission
    # refusals: the eight exceptions of chapter 4.5.3 all describe a server
    # handling a request, and none a sender that never submitted.
    it 'imputes no EDM exception to a correspondent no message reached' do
      choice

      expect(exchange.reload.edm_error_code).to be_nil
    end
  end

  context 'when the access point announces no version at all' do
    let(:recipient) { build(:access_point, :foreign, conforms_to: []) }

    it 'takes the preferred version: the directory said nothing, not no' do
      expect(choice).to be_success
      expect(exchange.reload.specification).to eq(EdmSpecification.preferred)
      expect(exchange.status).to eq('pending')
    end
  end
end
