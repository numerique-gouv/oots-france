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
      payload.merge!('statut' => 'failed', 'codeErreur' => 'EDM:ERR:0004')

      expect(wording.outcome).to eq(:refused)
    end

    # Chapter 4.10 §4.2, informative: no administration refused, the use of
    # OOTS is impossible.
    it 'is an unavailability when the exchange failed with no code' do
      payload['statut'] = 'failed'

      expect(wording.outcome).to eq(:unavailable)
    end

    # Chapter 4.10 §2.1: the portal tells the user, and does not wait for the
    # screen's deadline to do so.
    it 'is a refusal, at once, when no evidence matched' do
      payload['statut'] = 'unmatched'

      expect(wording.outcome).to eq(:refused)
    end

    # Chapter 4.9 §1: a user deciding not to use the evidence is answered an
    # empty list, which the contract says as `declined`.
    it 'says the user declined the document on the preview space' do
      payload['statut'] = 'declined'

      expect(wording.outcome).to eq(:declined)
    end

    # The departure page of chapter 4.9 §5: the link the confirmation handed
    # back, and the user not yet back from following it.
    describe 'the departure page' do
      before { request.preview_address = 'https://ap.example/preview' }

      it 'stands while the user has not come back' do
        payload['statut'] = 'pending'

        expect(wording.outcome).to eq(:preview)
      end

      it 'stands on a confirmation that has just been made, the state still awaiting it' do
        payload['statut'] = 'preview_required'

        expect(wording.outcome).to eq(:preview)
      end

      it 'never gives up, the time spent on the preview space being the user\'s' do
        request.created_at = 1.hour.ago

        expect(wording.outcome).to eq(:preview)
      end

      # A second exchange may settle without the user coming back.
      it 'leaves as soon as the second exchange failed' do
        payload.merge!('statut' => 'failed', 'codeErreur' => 'EDM:ERR:0004')

        expect(wording.outcome).to eq(:refused)
      end

      it 'leaves as soon as the second request could not be delivered' do
        payload['statut'] = 'failed'

        expect(wording.outcome).to eq(:unavailable)
      end

      it 'leaves as soon as the user declined' do
        payload['statut'] = 'declined'

        expect(wording.outcome).to eq(:declined)
      end

      it 'waits again once the user is back' do
        request.returned_at = Time.current

        expect(wording.outcome).to eq(:pending)
      end

      # Chapter 4.9 v1.2.3 §5 allows a `PUT`, which no HTML form sends.
      it 'says a link to be followed with a PUT cannot be presented' do
        request.preview_method = 'PUT'

        expect(wording.outcome).to eq(:unpresentable)
      end

      it 'decodes the fields of the form a POST sends' do
        request.preview_method = 'POST'
        request.preview_body = 'returnurl=https%3A%2F%2Ffr.example%2Fretour&returnmethod=GET'

        expect(wording).to be_preview_form
        expect(wording.preview_fields).to eq([%w[returnurl https://fr.example/retour], %w[returnmethod GET]])
      end
    end

    it 'says a confirmation that failed' do
      payload['statut'] = 'preview_required'
      wording = described_class.new(answer:, request:,
        unconfirmed: { key: :demo_preview_unconfirmed, errors: ['adresse refusée'] })

      expect(wording.outcome).to eq(:unconfirmed)
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
        payload.merge!('statut' => 'failed', 'codeErreur' => 'EDM:ERR:0004')

        expect(wording.outcome).to eq(:refused)
      end

      it 'leaves a failure of OOTS a failure of OOTS' do
        payload['statut'] = 'failed'

        expect(wording.outcome).to eq(:unavailable)
      end

      it 'leaves an answer that no evidence matches a refusal' do
        payload['statut'] = 'unmatched'

        expect(wording.outcome).to eq(:refused)
      end

      # Counted from the return when the user went to preview the document.
      describe 'after a visit to the preview space' do
        let(:now) { request.returned_at + described_class::GIVE_UP_AFTER + 1.second }

        before do
          request.created_at = 1.hour.ago
          request.preview_address = 'https://ap.example/preview'
          request.returned_at = Time.current
        end

        it 'gives up two minutes after the return' do
          expect(wording.outcome).to eq(:expired)
        end

        it 'is still waiting a moment before' do
          allow(clock).to receive(:now).and_return(request.returned_at + described_class::GIVE_UP_AFTER - 1.second)

          expect(wording.outcome).to eq(:pending)
        end
      end
    end
  end

  # The states in which the card stays in the country of its request: the zone
  # then follows that request, and offers no button to ask elsewhere.
  describe '#holds_country?' do
    it 'holds it while the exchange is under way' do
      expect(wording).to be_holds_country
    end

    it 'holds it once the document is in hand' do
      allow(request).to receive(:evidence?).and_return(true)

      expect(wording).to be_holds_country
    end

    it 'holds it while the departure page stands' do
      request.preview_address = 'https://ap.example/preview'

      expect(wording).to be_holds_country
    end

    it 'lets it go once the correspondent refused' do
      payload.merge!('statut' => 'failed', 'codeErreur' => 'EDM:ERR:0004')

      expect(wording).not_to be_holds_country
    end

    it 'lets it go once OOTS could not deliver the request' do
      payload['statut'] = 'failed'

      expect(wording).not_to be_holds_country
    end

    it 'lets it go once the screen gave up waiting' do
      request.created_at = 1.hour.ago

      expect(wording).not_to be_holds_country
    end

    it 'lets it go when the contract cannot say' do
      allow(answer).to receive(:status).and_return(404)

      expect(wording).not_to be_holds_country
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
