require 'rails_helper'

RSpec.describe Demo::ContractAnswer do
  subject(:answer) { described_class.new(status: 202, payload:) }

  let(:payload) { { 'echange' => 'un-échange', 'conversation' => 'une-conversation' } }

  it 'reads the two identifiers under the names the contract publishes them' do
    expect(answer).to have_attributes(exchange_id: 'un-échange', conversation_id: 'une-conversation')
  end

  describe 'what counts as an acceptance' do
    it 'is a 202 naming its exchange' do
      expect(answer).to be_accepted
    end

    # `EvidenceRequestsController` builds its `202` on an `Exchange`, so it
    # always names one: an acceptance without it is a body that did not arrive
    # whole, and showing it as a success would announce a request that left
    # while nothing can say which.
    it 'is not a 202 that names none' do
      expect(described_class.new(status: 202)).not_to be_accepted
    end

    it 'is no other status, whatever the body carries' do
      expect(described_class.new(status: 200, payload:)).not_to be_accepted
    end
  end

  # The feature switch answers `Not Implemented Yet!` as plain text, and a body
  # that parses to an array or a number parses without error: reading a field
  # has to stay one gesture whatever came back.
  describe 'a body that is no JSON object' do
    it 'reads as an answer carrying nothing' do
      expect(described_class.new(status: 501, payload: ['pas un objet']))
        .to have_attributes(accepted?: false, exchange_id: nil, error: nil)
    end

    it 'reads the same when no body was given at all' do
      expect(described_class.new(status: 502)).to have_attributes(accepted?: false, error: nil)
    end
  end

  it 'hands on the message a refusal carried' do
    refused = described_class.new(status: 422, payload: { 'erreur' => 'EB:ERR:0001' })

    expect(refused.error).to eq('EB:ERR:0001')
  end
end
