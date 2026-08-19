require 'rails_helper'

# The exchange log of chapter 4.8, exercised on the envelopes a real Domibus
# produced: what it records has to survive whatever a correspondent sends, and
# `incoming/reel/` is the only corpus that proves that.
RSpec.describe AuditTrail do
  subject(:audit_trail) { described_class.new }

  def journalled = AuditEvent.order(:id).last

  describe 'a request another member state addressed to France' do
    let(:message) { RetrievedMessageParser.new(real_envelope('requete')) }

    before { audit_trail.message_received(message:, message_id: 'message-passerelle') }

    it 'records what ties the exchange together' do
      expect(journalled).to have_attributes(
        event_type: 'request_received',
        ebms_action: EbmsAction::EXECUTE_QUERY_REQUEST,
        conversation_id: '1589c463-ccb7-4c0e-8044-c7198d844c16',
        exchange_id: '1647038b-7eaf-4711-b738-d5d83f96fa7b',
        message_id: 'message-passerelle',
        request_id: 'urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700',
      )
    end

    # « Party identifier for requesting authority », with its scheme: a bare
    # SIRET designates nobody outside France.
    it 'records both corners with their identifier scheme' do
      expect(journalled).to have_attributes(
        requesting_authority_id: '00000000000002',
        requesting_authority_scheme: 'urn:cef.eu:names:identifier:EAS:0009',
        providing_authority_id: Settings.french_provider_identity[:id],
      )
    end

    it 'records the subject of the evidence, and the key it is looked up by' do
      expect(journalled.evidence_subject).to include('Dupont', 'Sophie', '1965-11-25')
      expect(journalled.evidence_subject_key).to eq('dupont|sophie|1965-11-25')
    end

    # Two member states spell a name in two cases and mean one person; the key
    # is what an auditor asks « what circulated about this person » with.
    it 'folds the case, so one person yields one key' do
      shouting = envelope_with_body('requete') { |body| body.sub('Dupont', 'DUPONT') }
      audit_trail.message_received(message: shouting, message_id: 'un-autre')

      expect(journalled.evidence_subject_key).to eq('dupont|sophie|1965-11-25')
    end

    it 'records the business context' do
      expect(journalled).to have_attributes(procedure_code: '00', evidence_type_id: end_with('00000000-0000-0000-0000-000000000000'))
    end
  end

  describe 'an answer carrying evidence' do
    let(:message) { RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')) }

    before { audit_trail.message_received(message:, message_id: 'message-passerelle') }

    # The digest is of the evidence as this application holds it: what it proves
    # is that a document produced later is the one that went through. The route
    # to the signature Domibus put on the transmitted part is `message_id`,
    # which chapter 4.8 traces.
    it 'records the fingerprint of the evidence, and never the evidence' do
      expect(journalled).to have_attributes(
        event_type: 'response_received',
        evidence_digest: Digest::SHA256.hexdigest(message.evidence),
        mime_type: 'application/pdf',
      )
    end
  end

  describe 'an answer that refuses' do
    let(:message) { RetrievedMessageParser.new(real_envelope('erreurObjetIntrouvable')) }

    before { audit_trail.message_received(message:, message_id: 'message-passerelle') }

    it 'records the code and the reason the correspondent gave' do
      expect(journalled).to have_attributes(
        event_type: 'error_received',
        edm_error_code: 'EDM:ERR:0004',
        detail: 'Object not found',
      )
    end
  end

  # A request whose ER agent is missing: readable enough to say what was asked,
  # not enough to say who asked. What was read must survive what was not.
  describe 'a request one field of which cannot be read' do
    let(:message) { envelope_with_body('requete') { |body| body.sub('>ER<', '>IP<') } }

    it 'keeps the fields it did read' do
      audit_trail.message_received(message:, message_id: 'message-passerelle')

      expect(journalled).to have_attributes(
        event_type: 'request_received',
        request_id: 'urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700',
        procedure_code: '00',
        requesting_authority_id: nil,
        # Never unreadable — it comes from our own configuration — so it must
        # not go down with the correspondent's.
        providing_authority_id: Settings.french_provider_identity[:id],
      )
    end
  end

  # Article 17 asks for the errors as much as the exchanges: a message too
  # malformed to answer is exactly the one an operator will come looking for.
  describe 'a message whose body cannot be read' do
    let(:message) { envelope_with_body('requete') { |body| body.sub('QueryRequest', 'Charabia') } }

    it 'records it all the same, on what the header alone gives' do
      expect { audit_trail.message_received(message:, message_id: 'message-passerelle') }.not_to raise_error

      expect(journalled).to have_attributes(
        event_type: 'request_received',
        conversation_id: '1589c463-ccb7-4c0e-8044-c7198d844c16',
        request_id: nil,
      )
    end
  end

  # These never reach the gateway, so no Domibus log holds them.
  describe 'a call this application turns down' do
    it 'records the refusal and its reason' do
      audit_trail.request_refused(requester_id: '00000000000002', procedure_code: 'T3', country_code: 'FI',
        reason: 'Démarche inconnue')

      expect(journalled).to have_attributes(
        event_type: 'request_refused',
        evidence_requester_id: '00000000000002',
        procedure_code: 'T3',
        country_code: 'FI',
        detail: 'Démarche inconnue',
        conversation_id: nil,
      )
    end

    # A refusal by the gateway comes later than the others: `OpenConversation`
    # has run, so there is an exchange to hang the refusal on.
    it 'names the conversation when one was already opened' do
      conversation = create(:conversation)

      audit_trail.request_refused(
        requester_id: '00000000000002', procedure_code: '00', country_code: 'FI',
        reason: 'Connexion refusée', conversation:,
      )

      expect(journalled.conversation_id).to eq(conversation.conversation_id)
    end
  end
end
