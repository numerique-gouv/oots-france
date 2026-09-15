require 'rails_helper'

RSpec.describe DemoOutcomeWording do
  subject(:wording) { described_class.new(answer:, request:) }

  let(:request) { Demo::Request.new(exchange_id: 'echange-1', conversation_id: 'conversation-1') }
  let(:answer) { Demo::ContractAnswer.new(status: 200, payload:) }
  let(:payload) { { 'statut' => 'sent' } }

  describe '#outcome' do
    # On a request with no `created_at`, which is one this register has not
    # recorded: nothing has been asked, so nothing can have waited too long.
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

    # The deadline is the screen's and not the exchange's: nothing bounds how
    # long an answer takes, so the zone stops asking rather than the exchange
    # stopping.
    describe 'the deadline the screen keeps' do
      subject(:wording) { described_class.new(answer:, request:, clock:) }

      let(:clock) { instance_double(Clock, now:) }
      let(:now) { request.created_at + described_class::GIVE_UP_AFTER + 1.second }

      before { request.created_at = Time.current }

      it 'gives up on a wait older than it' do
        expect(wording.outcome).to eq(:expired)
      end

      it 'is still waiting a moment before it' do
        allow(clock).to receive(:now).and_return(request.created_at + described_class::GIVE_UP_AFTER - 1.second)

        expect(wording.outcome).to eq(:pending)
      end

      # The document in hand settles it whatever the clock says: an answer that
      # arrived is not a wait that ran out.
      it 'never gives up on a request the document has come back on' do
        allow(request).to receive(:evidence?).and_return(true)

        expect(wording.outcome).to eq(:delivered)
      end

      # A refusal is what happened, and saying the screen ran out of patience
      # instead would send the reader looking for an answer that was given.
      it 'leaves a refusal a refusal' do
        payload['statut'] = 'failed'

        expect(wording.outcome).to eq(:refused)
      end
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
