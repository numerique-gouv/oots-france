require 'rails_helper'

RSpec.describe Demo::Request do
  subject(:request) { described_class.new(exchange_id: 'echange-1', conversation_id: 'conversation-1') }

  it { is_expected.to validate_presence_of(:exchange_id) }
  it { is_expected.to validate_presence_of(:conversation_id) }

  describe '#answers?' do
    # Chapter 4.4 §4.3.2 gives each identifier its own job, so both are asked of
    # a delivery.
    it 'recognises a delivery naming both of its identifiers' do
      expect(request.answers?('echange-1', 'conversation-1')).to be(true)
    end

    it 'refuses one naming its exchange under another conversation' do
      expect(request.answers?('echange-1', 'conversation-2')).to be(false)
    end
  end

  describe '#receive_evidence!' do
    let(:content) { "%PDF-1.4\ndrapeau".b }

    before { request.save! }

    # Chapter 1 §4.2: the user « cannot modify its content in any way », so what
    # is filed is what arrived, and the digest is taken of those same bytes.
    it 'files the bytes as they arrived, with their digest' do
      request.receive_evidence!(content)

      expect(request.reload.evidence).to eq(content)
      expect(request.evidence_digest).to eq(Digest::SHA256.hexdigest(content))
    end

    it 'is what makes the request one that has its evidence' do
      expect { request.receive_evidence!(content) }.to change(request, :evidence?).from(false).to(true)
    end
  end
end
