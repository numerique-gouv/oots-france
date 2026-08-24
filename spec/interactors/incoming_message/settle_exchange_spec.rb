require 'rails_helper'

RSpec.describe IncomingMessage::SettleExchange do
  subject(:settle) { described_class.call(message:, evidence_forwarder:, requesters:, audit_trail: AuditTrail.new) }

  let(:evidence_forwarder) { instance_double(EvidenceForwarder, deliver: nil) }
  let(:requesters) do
    Directories::EvidenceRequesters.new(
      '00000000000002' => { 'nom' => 'Requêteur', 'url' => 'http://localhost:4000' },
    )
  end
  let(:message) { RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')) }
  let!(:exchange) { create(:exchange, exchange_id: message.exchange_id).tap(&:sent!) }

  # Chapter 4.4: « An Online Procedure Portal MUST NOT process responses that
  # use request identifiers of previous requests to which it already received a
  # response. » Neither refusal answers the correspondent — the TDD open no
  # error path back from a portal to a provider.
  describe 'what it refuses to process' do
    context 'when the exchange has already been answered' do
      before { exchange.delivered! }

      # Not merely « does not settle twice »: `deliver` hands the evidence over
      # before it marks the exchange delivered, so a duplicate not turned away
      # here reaches the French service provider a second time.
      it 'does not hand the evidence over again' do
        settle

        expect(evidence_forwarder).not_to have_received(:deliver)
      end
    end

    context 'when the response carries an identifier that is not ours' do
      before { exchange.update!(request_id: 'urn:uuid:00000000-0000-4000-8000-000000000000') }

      it 'does not hand the evidence over' do
        settle

        expect(evidence_forwarder).not_to have_received(:deliver)
      end

      # Left pending on purpose: the message was not ours to begin with, and
      # failing the exchange would rob the genuine answer of the exchange it
      # still has to reach.
      it 'leaves the exchange waiting for the answer it did ask for' do
        settle

        expect(exchange.reload).to have_attributes(status: 'sent')
      end
    end

    # The guard sits above the branch on the ebMS action, so an error response is
    # turned away on the same two grounds as one carrying evidence. Moving it
    # down into `deliver` would look like a simplification and would silently
    # stop refusing duplicate error responses.
    context 'when a duplicate error response arrives on a settled exchange' do
      let(:message) { RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')) }

      before { exchange.delivered! }

      it 'leaves the outcome the exchange already reached' do
        settle

        expect(exchange.reload).to have_attributes(status: 'delivered', edm_error_code: nil)
      end
    end

    # Nothing goes back to the correspondent, so the journal is the only place
    # the decision can be read afterwards — an exchange left waiting has to be
    # accountable for.
    it 'journals what the response was turned away for' do
      exchange.update!(request_id: 'urn:uuid:00000000-0000-4000-8000-000000000000')

      settle

      expect(AuditEvent.last).to have_attributes(
        event_type: 'response_refused',
        exchange_id: exchange.exchange_id,
        detail: 'foreign_request',
      )
    end

    # An identifier we never recorded is not a different one: exchanges opened
    # before the column existed carry none.
    context 'when the exchange records no request identifier' do
      it 'delivers, rather than refusing what it cannot compare' do
        settle

        expect(evidence_forwarder).to have_received(:deliver)
      end
    end

    context 'when the response echoes the identifier the request carried' do
      before { exchange.update!(request_id: message.body.request_id) }

      it 'delivers' do
        settle

        expect(evidence_forwarder).to have_received(:deliver)
      end
    end
  end

  # An expiry is a guess that no answer will come, and this one did. Chapter 4.4
  # forbids processing a response to a request « to which it already received a
  # response » — an exchange the sweep gave up on received none, so this answer
  # is the first, however late.
  describe 'an answer arriving after the sweep gave the exchange up' do
    let(:message) { RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')) }

    before { exchange.expire! }

    it 'hands the evidence over all the same' do
      settle

      expect(evidence_forwarder).to have_received(:deliver)
    end

    it 'records the delivery, overruling the presumption' do
      settle

      expect(exchange.reload).to have_attributes(status: 'delivered', edm_error_code: nil)
    end
  end

  describe 'an answer carrying evidence' do
    # Resolved from the directory, which is what carries the address the
    # forwarder posts to: an identifier alone would deliver the evidence
    # nowhere.
    it 'hands it to the requester that asked' do
      settle

      expect(evidence_forwarder).to have_received(:deliver)
        .with(start_with('%PDF'), have_attributes(id: '00000000000002', url: 'http://localhost:4000'))
    end

    it 'records the exchange as delivered' do
      settle

      expect(exchange.reload).to have_attributes(status: 'delivered')
    end

    # What became of the evidence is the last thing chapter 4.8 asks a requester
    # to log, and one of the two events no ebMS message stands for — the other
    # being the refusal this application opposes before the gateway.
    it 'journals the delivery, with the fingerprint of what was handed over' do
      settle

      expect(AuditEvent.last).to have_attributes(
        event_type: 'evidence_delivered',
        exchange_id: exchange.exchange_id,
        country_code: exchange.country_code,
        evidence_digest: Digest::SHA256.hexdigest(message.evidence),
      )
    end
  end

  # Chapter 4.5.2: a status of `Unavailable` announces the evidence for later
  # and carries none. It is an answer, not a failure — and not the tort the
  # missing PDF payload used to make it, an exchange settled « illisible » and
  # closed to the request that would have retrieved the document.
  describe 'an answer announcing the evidence for later' do
    let(:message) { RetrievedMessageParser.new(built_envelope('reponseDifferee')) }

    it 'records the date the correspondent announced' do
      settle

      expect(exchange.reload).to have_attributes(
        status: 'deferred',
        response_available_at: Time.zone.parse('2026-08-07T10:00:00Z'),
      )
    end

    it 'does not read the exchange as a failure' do
      settle

      expect(exchange.reload).to have_attributes(edm_error_code: nil, error_description: nil)
    end

    it 'hands nothing over, there being nothing to hand over' do
      settle

      expect(evidence_forwarder).not_to have_received(:deliver)
    end

    # The reservation exists to keep two workers from handing the same document
    # over twice. Taking it for an answer that hands nothing over would leave it
    # standing on an exchange no delivery is coming to.
    it 'reserves no delivery' do
      settle

      expect(exchange.reload.delivering_at).to be_nil
    end

    # Chapter 4.4 again: the announcement is the response this request received,
    # so the document arrives on a new Evidence Request, never on this one. The
    # guard that turns it away is `already_settled`, which `processable?` reads
    # before it ever compares the two request identifiers.
    it 'turns away the evidence when it arrives on the exchange the announcement settled' do
      exchange.update!(request_id: message.body.request_id)
      settle

      described_class.call(message: RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')),
        evidence_forwarder:, requesters:, audit_trail: AuditTrail.new)

      expect(evidence_forwarder).not_to have_received(:deliver)
      expect(AuditEvent.last).to have_attributes(event_type: 'response_refused', detail: 'already_settled')
    end

    # `R-EDM-RESP-S045` makes the slot mandatory, and a correspondent that omits
    # it has still not failed: the exchange ends announced, with no date to show.
    context 'when the announcement names no readable date' do
      let(:message) do
        document = Nokogiri::XML(built_envelope('reponseDifferee'))
        value = document.xpath('//payload/value').first
        value.content = Base64.strict_encode64(
          Base64.decode64(value.text).sub(%r{<rim:Slot name="ResponseAvailableDateTime">.*?</rim:Slot>}m, ''),
        )

        RetrievedMessageParser.new(document.to_xml)
      end

      it 'settles the exchange all the same' do
        settle

        expect(exchange.reload).to have_attributes(status: 'deferred', response_available_at: nil)
      end
    end
  end

  describe 'a refusal' do
    let(:message) { RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')) }

    it 'records the EDM code, which is what the caller can act on' do
      settle

      expect(exchange.reload).to have_attributes(status: 'failed', edm_error_code: 'EDM:ERR:0004')
    end

    # The likeliest of the late answers: a correspondent that says at last it
    # holds nothing. The caller is owed the code it was told, not the one this
    # side guessed while waiting for it.
    context 'when it arrives after the sweep gave the exchange up' do
      before { exchange.expire! }

      it 'records what the correspondent said, in place of the guess' do
        settle

        expect(exchange.reload).to have_attributes(edm_error_code: 'EDM:ERR:0004', presumed_at: nil)
      end
    end
  end

  describe 'a request for a preview' do
    let(:message) { RetrievedMessageParser.new(built_envelope('erreurAutorisationRequise')) }

    # Not a failure: an instruction to send the user somewhere before asking
    # again. This is where chapter 4.9 will resume from.
    it 'records where to send the user' do
      settle

      expect(exchange.reload).to have_attributes(
        status: 'preview_required',
        preview_location: 'https://previsualisation.example.si/espace?jeton=abc',
      )
    end
  end

  # An address whose scheme we do not accept is no address at all: a
  # correspondent asking for a preview without saying where has failed the
  # exchange, and sending the user to a link of its choosing is not an option.
  describe 'a preview at an address it will not follow' do
    let(:message) do
      RetrievedMessageParser.new(hostile_preview('javascript:alert(document.domain)'))
    end

    it 'records a failure rather than a link' do
      settle

      expect(exchange.reload).to have_attributes(status: 'failed', preview_location: nil)
    end
  end

  # Two responses for one exchange — two ebMS messages, so the destructive read
  # of `retrieveMessage` turns neither away. `processable?` cannot decide
  # between them: both read the row before either writes, and the handover is a
  # POST nothing takes back.
  describe 'a second response arriving while the first is being handed over' do
    # The counter is what bounds the recursion: the second pass is refused
    # before it reaches the forwarder, and were it not, the example would fail
    # on the count rather than run away.
    before do
      arrivals = 0

      allow(evidence_forwarder).to receive(:deliver) do
        arrivals += 1
        described_class.call(message:, evidence_forwarder:, requesters:, audit_trail: AuditTrail.new) if arrivals == 1
      end
    end

    it 'hands the evidence over once' do
      settle

      expect(evidence_forwarder).to have_received(:deliver).once
    end

    # Article 17 answers for what was handed over, so two lines for one
    # handover misstate the exchange as plainly as two handovers would.
    it 'records one delivery and the refusal of the other response' do
      settle

      expect(AuditEvent.where(exchange_id: exchange.exchange_id).pluck(:event_type, :detail))
        .to contain_exactly(%w[response_refused already_delivering], ['evidence_delivered', nil])
    end

    it 'settles the exchange as delivered' do
      settle

      expect(exchange.reload).to have_attributes(status: 'delivered')
    end
  end

  # The race above always ends with the winner delivering. This one is the
  # exchange whose winner never comes back — the reservation stands, and the
  # loser must still be turned away rather than hand the evidence over.
  context 'when another worker holds the reservation' do
    before { Exchange.find(exchange.id).claim_delivery! }

    it 'does not hand the evidence over' do
      settle

      expect(evidence_forwarder).not_to have_received(:deliver)
    end

    it 'leaves the exchange for the worker that took it' do
      settle

      expect(exchange.reload).to have_attributes(status: 'sent')
    end
  end

  # The reservation is deliberately one-way: `IncomingMessage::Process` settles
  # the exchange on a handover that raises, so giving it back would only let a
  # later response re-enter a delivery whose outcome nobody knows.
  it 'keeps the reservation when the handover fails' do
    allow(evidence_forwarder).to receive(:deliver).and_raise(Faraday::ConnectionFailed, 'connexion refusée')

    expect { settle }.to raise_error(Faraday::ConnectionFailed)
    expect(exchange.reload.delivering_at).to be_present
  end

  # `processable?` lets a presumed exchange through, so two late responses both
  # reach the handover — the one composition where the exchange's own age can no
  # longer tell the reservation anything.
  context 'when the sweep had already given the exchange up' do
    before do
      exchange.update_columns(created_at: Settings.requester_timeout.ago - 1.day)
      exchange.expire!

      arrivals = 0

      allow(evidence_forwarder).to receive(:deliver) do
        arrivals += 1
        described_class.call(message:, evidence_forwarder:, requesters:, audit_trail: AuditTrail.new) if arrivals == 1
      end
    end

    it 'hands the evidence over once' do
      settle

      expect(evidence_forwarder).to have_received(:deliver).once
    end

    it 'settles the exchange as delivered, the answer refuting the presumption' do
      settle

      expect(exchange.reload).to have_attributes(status: 'delivered', presumed_at: nil)
    end
  end

  # The reason travels as a symbol. The branches that give one are exercised
  # above, but never for the wording it resolves to: nothing else would notice a
  # missing one.
  it 'says every reason it turns a response away for' do
    refused = File.read('app/interactors/incoming_message/settle_exchange.rb')
      .scan(/refuse\(exchange, :(\w+)\)/).flatten.uniq

    expect_said(refused.map { |reason| "interactors.incoming_message.settle_exchange.#{reason}" })
  end

  # A notification for an exchange we never opened: a message meant for someone
  # else, or one that outlived its exchange. Recorded, not raised — there is
  # nobody to report it to.
  it 'does not fail on an exchange it does not know' do
    Exchange.delete_all

    expect { settle }.not_to raise_error
  end

  def hostile_preview(location)
    document = Nokogiri::XML(built_envelope('erreurAutorisationRequise'))
    value = document.xpath('//payload/value').first
    body = Base64.decode64(value.text).sub(/(<rim:Slot name="PreviewLocation">.*?<rim:Value>)[^<]*/m, "\\1#{location}")
    value.content = Base64.strict_encode64(body)

    document.to_xml
  end
end
