require 'rails_helper'

RSpec.describe IncomingMessage::SettleConversation do
  subject(:settle) { described_class.call(message:, evidence_forwarder:, requesters:, audit_trail: AuditTrail.new) }

  let(:evidence_forwarder) { instance_double(EvidenceForwarder, deliver: nil) }
  let(:requesters) do
    Directories::EvidenceRequesters.new(
      '00000000000002' => { 'nom' => 'Requêteur', 'url' => 'http://localhost:4000' },
    )
  end
  let(:message) { RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')) }
  let!(:conversation) { create(:conversation, conversation_id: message.conversation_id).tap(&:sent!) }

  # Chapter 4.4: « An Online Procedure Portal MUST NOT process responses that
  # use request identifiers of previous requests to which it already received a
  # response. » Neither refusal answers the correspondent — the TDD open no
  # error path back from a portal to a provider.
  describe 'what it refuses to process' do
    context 'when the exchange has already been answered' do
      before { conversation.delivered! }

      # Not merely « does not settle twice »: `deliver` hands the evidence over
      # before it marks the exchange delivered, so a duplicate not turned away
      # here reaches the French service provider a second time.
      it 'does not hand the evidence over again' do
        settle

        expect(evidence_forwarder).not_to have_received(:deliver)
      end
    end

    context 'when the response carries an identifier that is not ours' do
      before { conversation.update!(request_id: 'urn:uuid:00000000-0000-4000-8000-000000000000') }

      it 'does not hand the evidence over' do
        settle

        expect(evidence_forwarder).not_to have_received(:deliver)
      end

      # Left pending on purpose: the message was not ours to begin with, and
      # failing the exchange would rob the genuine answer of the conversation it
      # still has to reach.
      it 'leaves the exchange waiting for the answer it did ask for' do
        settle

        expect(conversation.reload).to have_attributes(status: 'sent')
      end
    end

    # The guard sits above the branch on the ebMS action, so an error response is
    # turned away on the same two grounds as one carrying evidence. Moving it
    # down into `deliver` would look like a simplification and would silently
    # stop refusing duplicate error responses.
    context 'when a duplicate error response arrives on a settled exchange' do
      let(:message) { RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')) }

      before { conversation.delivered! }

      it 'leaves the outcome the exchange already reached' do
        settle

        expect(conversation.reload).to have_attributes(status: 'delivered', edm_error_code: nil)
      end
    end

    # Nothing goes back to the correspondent, so the journal is the only place
    # the decision can be read afterwards — an exchange left waiting has to be
    # accountable for.
    it 'journals what the response was turned away for' do
      conversation.update!(request_id: 'urn:uuid:00000000-0000-4000-8000-000000000000')

      settle

      expect(AuditEvent.last).to have_attributes(
        event_type: 'response_refused',
        conversation_id: conversation.conversation_id,
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
      before { conversation.update!(request_id: message.body.request_id) }

      it 'delivers' do
        settle

        expect(evidence_forwarder).to have_received(:deliver)
      end
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

    it 'records the conversation as delivered' do
      settle

      expect(conversation.reload).to have_attributes(status: 'delivered')
    end

    # What became of the evidence is the last thing chapter 4.8 asks a requester
    # to log, and one of the two events no ebMS message stands for — the other
    # being the refusal this application opposes before the gateway.
    it 'journals the delivery, with the fingerprint of what was handed over' do
      settle

      expect(AuditEvent.last).to have_attributes(
        event_type: 'evidence_delivered',
        conversation_id: conversation.conversation_id,
        country_code: conversation.country_code,
        evidence_digest: Digest::SHA256.hexdigest(message.evidence),
      )
    end
  end

  describe 'a refusal' do
    let(:message) { RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')) }

    it 'records the EDM code, which is what the caller can act on' do
      settle

      expect(conversation.reload).to have_attributes(status: 'failed', edm_error_code: 'EDM:ERR:0004')
    end
  end

  describe 'a request for a preview' do
    let(:message) { RetrievedMessageParser.new(built_envelope('erreurAutorisationRequise')) }

    # Not a failure: an instruction to send the user somewhere before asking
    # again. This is where chapter 4.9 will resume from.
    it 'records where to send the user' do
      settle

      expect(conversation.reload).to have_attributes(
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

      expect(conversation.reload).to have_attributes(status: 'failed', preview_location: nil)
    end
  end

  # A notification for an exchange we never opened: a message meant for someone
  # else, or one that outlived its conversation. Recorded, not raised — there is
  # nobody to report it to.
  it 'does not fail on a conversation it does not know' do
    Conversation.delete_all

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
