require 'rails_helper'

RSpec.describe DemoOutcomeWording do
  subject(:wording) { described_class.new(answer:, request:) }

  let(:request) { Demo::Request.new(exchange_id: 'echange-1', conversation_id: 'conversation-1') }
  let(:answer) { Demo::ContractAnswer.new(status: 200, payload:) }
  let(:payload) { { 'statut' => 'sent' } }

  describe '#outcome' do
    it 'is pending while nothing has come back' do
      expect(wording.outcome).to eq(:pending)
    end

    it 'is a refusal when the exchange failed' do
      payload['statut'] = 'failed'

      expect(wording.outcome).to eq(:refused)
    end

    it 'is a preview when the correspondent asked for one' do
      payload['statut'] = 'preview_required'

      expect(wording.outcome).to eq(:preview)
    end

    # The evidence in hand settles it, whichever process wrote last.
    it 'is delivered as soon as the evidence has been filed, whatever the state says' do
      allow(request).to receive(:evidence?).and_return(true)

      expect(wording.outcome).to eq(:delivered)
    end

    it 'is still pending when the state says delivered and nothing has been filed' do
      payload['statut'] = 'delivered'

      expect(wording.outcome).to eq(:pending)
    end

    # The demonstration asks only for `T1`, which France always serves with a
    # document, so `deferred` never reaches this page; it reads as waiting
    # rather than as a case of its own — the ticket puts it out of scope.
    it 'reads a state it has nothing to say about as waiting' do
      payload['statut'] = 'deferred'

      expect(wording.outcome).to eq(:pending)
    end
  end

  describe '#secure_preview?' do
    # Chapter 4.9 §4: « specify secure HTTP ("https://") as transport. The use
    # of "http://" URIs is not allowed. »
    it 'is true of an https address' do
      payload['adressePrevisualisation'] = 'https://ap.example/preview'

      expect(wording).to be_secure_preview
    end

    it 'is false of the http the chapter forbids' do
      payload['adressePrevisualisation'] = 'http://ap.example/preview'

      expect(wording).not_to be_secure_preview
    end

    it 'is false of no address at all' do
      expect(wording).not_to be_secure_preview
    end
  end

  describe '#unreadable?' do
    it 'is false when the contract answered about the exchange' do
      expect(wording).not_to be_unreadable
    end

    it 'is true when the contract refused to' do
      allow(answer).to receive(:status).and_return(404)

      expect(wording).to be_unreadable
    end
  end
end
