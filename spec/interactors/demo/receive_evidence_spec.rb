require 'rails_helper'

RSpec.describe Demo::ReceiveEvidence do
  let(:content) { "%PDF-1.4\ndrapeau".b }
  let(:arguments) do
    { exchange_id: DemoContractStubs::ACCEPTED_EXCHANGE,
      conversation_id: DemoContractStubs::ACCEPTED_CONVERSATION, evidence: content }
  end

  context 'when the procedure opened the request the delivery names' do
    before { registered_request }

    it 'files the evidence on it' do
      expect(described_class.call(**arguments)).to be_success
      expect(Demo::Request.sole.evidence).to eq(content)
    end
  end

  # Chapter 4.10 §4.1, informative: « In case this value is not linked to any
  # known current user and/or user session, the event is logged for
  # investigation. » CA5: no page shows it, and the application log carries the
  # event.
  context 'when it names no request this procedure opened' do
    it 'files nothing and fails' do
      result = described_class.call(**arguments)

      expect(result).to be_failure
      expect(result.error[:key]).to eq(:demo_unplaceable)
      expect(Demo::Request.count).to be_zero
    end

    it 'logs the event for investigation, naming both identifiers' do
      allow(Rails.logger).to receive(:warn)

      described_class.call(**arguments)

      expect(Rails.logger).to have_received(:warn)
        .with(a_string_including(DemoContractStubs::ACCEPTED_EXCHANGE, 'aucune demande'))
    end

    it 'refuses a delivery naming a known exchange under another conversation' do
      registered_request

      result = described_class.call(**arguments, conversation_id: 'une-autre-conversation')

      expect(result).to be_failure
      expect(Demo::Request.sole.evidence).to be_nil
    end

    it 'refuses one naming no exchange at all' do
      registered_request

      expect(described_class.call(**arguments, exchange_id: nil)).to be_failure
    end
  end

  context 'when the delivery carries no bytes' do
    before { registered_request }

    it 'files nothing and says the delivery was empty' do
      result = described_class.call(**arguments, evidence: '')

      expect(result.error[:key]).to eq(:demo_evidence_empty)
      expect(Demo::Request.sole.evidence).to be_nil
    end
  end
end
