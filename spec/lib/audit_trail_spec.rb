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
        country_code: 'FR',
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

    # Chapter 4.8, in both its tables: « MIME type and full content of first
    # MIME part ». Byte for byte and not `include`: what is kept is what
    # circulated, and Domibus erased it as it handed it over.
    it 'keeps the first MIME part whole, under the type the correspondent declared' do
      expect(journalled).to have_attributes(
        regrep_mime_type: 'application/x-ebrs+xml',
        regrep_body: message.first_part.content,
      )
      expect(journalled.regrep_body).to start_with('<?xml').and include('QueryRequest')
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
        evidence_mime_type: 'application/pdf',
        country_code: 'FR',
      )
    end

    # Chapter 4.8 asks the response flow for both parties, the response
    # identifier and the evidence identifier. The correlation identifiers come
    # from the header either way, so what is missing here is detail rather than
    # trace — but it is the detail an auditor reconciles a document by.
    it 'records the identifiers chapter 4.8 asks the response flow for' do
      expect(journalled).to have_attributes(
        request_id: message.body.request_id,
        response_id: message.body.response_id,
        evidence_identifier: message.body.evidence_identifier,
      )
    end

    it 'records both parties of the exchange' do
      expect(journalled).to have_attributes(
        requesting_authority_id: message.body.requester.ebms_identity.id,
        requesting_authority_scheme: message.body.requester.ebms_identity.type_id,
        providing_authority_id: message.body.provider.ebms_identity.id,
        providing_authority_scheme: message.body.provider.ebms_identity.type_id,
      )
    end

    # No personal data on this side: chapter 4.8 lists the evidence subject in
    # the request flow, where the journal already holds it, and not here.
    it 'records no subject' do
      expect(journalled).to have_attributes(evidence_subject: nil, evidence_subject_key: nil)
    end

    # The chapter asks for the *first* part. The evidence travels in a second
    # one, and it is the fingerprint that stands for it — the journal is not
    # where a PDF is kept.
    it 'keeps the metadata document and never the evidence beside it' do
      expect(journalled.regrep_body).to eq(message.first_part.content)
      expect(journalled.regrep_body).to include('QueryResponse')
      expect(journalled.regrep_body).not_to include('%PDF')
    end
  end

  # A deferral is journalled like any other response received: the body carries
  # neither evidence metadata nor a PDF payload, and `readable` is what keeps
  # both absences from costing the line itself.
  describe 'an answer announcing the evidence for later' do
    let(:message) { RetrievedMessageParser.new(built_envelope('reponseDifferee')) }

    before { audit_trail.message_received(message:, message_id: 'message-passerelle') }

    it 'records the arrival, with no fingerprint to record' do
      expect(journalled).to have_attributes(
        event_type: 'response_received',
        evidence_digest: nil,
        evidence_mime_type: nil,
      )
    end

    it 'still records what correlates the answer to its request' do
      expect(journalled).to have_attributes(
        conversation_id: message.conversation_id,
        request_id: message.body.request_id,
        response_id: message.body.response_id,
      )
    end

    it 'keeps the announcement itself' do
      expect(journalled.regrep_body).to eq(message.first_part.content)
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
        country_code: 'FR',
      )
    end

    it 'keeps the rs:Exception as it arrived' do
      expect(journalled.regrep_body).to eq(message.first_part.content)
      expect(journalled.regrep_body).to include('rs:Exception', 'EDM:ERR:0004')
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
        # The country travels on that same agent's address, and nowhere else.
        country_code: nil,
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

    # The whole point of reading the part past Nokogiri: the bytes nobody could
    # make sense of are the ones an auditor most needs, and the gateway has
    # already destroyed them.
    it 'keeps the bytes it could make nothing of' do
      audit_trail.message_received(message:, message_id: 'message-passerelle')

      expect(journalled.regrep_body).to include('Charabia')
      expect(journalled).to have_attributes(regrep_mime_type: 'application/x-ebrs+xml', request_id: nil)
    end
  end

  # Nothing in the TDD fixes an encoding, and the chapter asks for the content
  # whole. Kept as it came, then, rather than refused or transcoded — the log
  # holds what circulated, well formed or not, and the console showing it garbled
  # is a defect of the screen, not of the trace.
  describe 'a message whose first part is not encoded in UTF-8' do
    let(:message) { envelope_with_body('requete') { "<query:QueryRequest>\xE9</query:QueryRequest>" } }

    it 'keeps the bytes as they came' do
      audit_trail.message_received(message:, message_id: 'message-passerelle')

      expect(journalled).to have_attributes(
        event_type: 'request_received',
        regrep_mime_type: 'application/x-ebrs+xml',
      )
      expect(journalled.regrep_body.bytes).to include(0xE9)
    end
  end

  # What the header declares, and not what it ought to declare: chapter 4.7.1
  # fixes `eb:PartInfo[1]` as the RegRep document, so a correspondent placing
  # something else there is the discrepancy an auditor comes to see.
  describe 'a message whose first part is not the one the chapter fixes' do
    let(:message) do
      RetrievedMessageParser.new(real_envelope('requete').sub('application/x-ebrs+xml', 'application/pdf'))
    end

    it 'records the type as declared, uncorrected' do
      audit_trail.message_received(message:, message_id: 'message-passerelle')

      expect(journalled).to have_attributes(event_type: 'request_received', regrep_mime_type: 'application/pdf')
      expect(journalled.regrep_body).to include('QueryRequest')
    end
  end

  describe 'a message announcing a part that is not there' do
    let(:message) { envelope_without('requete', '//ws:retrieveMessageResponse/payload') }

    it 'records the arrival all the same, with nothing to show for the part' do
      expect { audit_trail.message_received(message:, message_id: 'message-passerelle') }.not_to raise_error

      expect(journalled).to have_attributes(
        event_type: 'request_received',
        regrep_mime_type: nil,
        regrep_body: nil,
        conversation_id: '1589c463-ccb7-4c0e-8044-c7198d844c16',
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

    # A refusal by the gateway comes later than the others: `OpenExchange`
    # has run, so there is an exchange to hang the refusal on.
    it 'names both the exchange and the conversation when one was already opened' do
      exchange = create(:exchange)

      audit_trail.request_refused(
        requester_id: '00000000000002', procedure_code: '00', country_code: 'FI',
        reason: 'Connexion refusée', exchange:,
      )

      expect(journalled).to have_attributes(
        exchange_id: exchange.exchange_id,
        conversation_id: exchange.conversation_id,
      )
    end
  end

  # Chapter 4.8 asks both its tables for it, so the duty runs both ways. What
  # France emits is
  # journalled from the envelope that carried it, so the log holds the message
  # as submitted and not a second rendering of it.
  describe 'what the journal keeps of what France sends' do
    let(:first_part) { MimePart.new(mime_type: 'application/x-ebrs+xml', content: '<query:QueryRequest/>') }
    let(:answered) do
      { message: RetrievedMessageParser.new(real_envelope('requete')), requester: nil, provider: nil,
        request_id: 'urn:uuid:x', response_id: 'urn:uuid:y', message_id: 'message-passerelle', first_part: }
    end

    it 'keeps the request it submitted' do
      audit_trail.request_sent(exchange: create(:exchange), requester: nil, provider: nil, beneficiary: nil,
        evidence_type: nil, request_id: 'urn:uuid:x', message_id: 'message-passerelle', first_part:)

      expect(journalled).to have_attributes(
        event_type: 'request_sent',
        regrep_mime_type: 'application/x-ebrs+xml',
        regrep_body: '<query:QueryRequest/>',
      )
    end

    it 'keeps the answer and the refusal alike' do
      audit_trail.response_sent(**answered, evidence: nil)
      expect(journalled).to have_attributes(event_type: 'response_sent', regrep_body: first_part.content)

      audit_trail.error_sent(**answered, exception: EdmException::OBJECT_NOT_FOUND)
      expect(journalled).to have_attributes(event_type: 'error_sent', regrep_body: first_part.content,
        evidence_identifier: nil)
    end

    # Chapter 4.8 asks the response flow for the evidence identifier from the
    # data service as much as from the requester, so what France answers with
    # says which document it was — and an answer carrying none says so by
    # leaving the column empty rather than by inventing a value.
    it 'names the evidence its own answer carried, and names none when it carried none' do
      carried = Evidence.new(content: 'un document', identifier: 'urn:uuid:z')

      audit_trail.response_sent(**answered, evidence: carried)
      expect(journalled).to have_attributes(
        event_type: 'response_sent', evidence_identifier: 'urn:uuid:z',
        evidence_digest: Digest::SHA256.hexdigest('un document'),
      )

      audit_trail.response_sent(**answered, evidence: nil)
      expect(journalled).to have_attributes(
        event_type: 'response_sent', evidence_identifier: nil, evidence_digest: nil,
      )
    end

    # One line covers both answers, so it is the only one that has to work out
    # which it is holding. Asserted here rather than only through the
    # interactor, where the choice of answer and the failure to send it are
    # entangled.
    it 'keeps the answer the gateway would not take, refusal and document alike' do
      unsent = { message: RetrievedMessageParser.new(real_envelope('requete')), requester: nil, provider: nil,
                 request_id: 'urn:uuid:x', response_id: 'urn:uuid:y', message_id: nil, first_part: }

      audit_trail.answer_not_sent(**unsent, reason: 'connexion refusée')
      expect(journalled).to have_attributes(
        event_type: 'answer_not_sent', ebms_action: EbmsAction::EXECUTE_QUERY_RESPONSE,
        edm_error_code: nil, message_id: nil, detail: 'connexion refusée',
        regrep_body: first_part.content,
      )

      audit_trail.answer_not_sent(**unsent, exception: EdmException::OBJECT_NOT_FOUND, reason: 'connexion refusée')
      expect(journalled).to have_attributes(
        ebms_action: EbmsAction::EXCEPTION_RESPONSE, edm_error_code: 'EDM:ERR:0004',
      )
    end
  end

  # An arrival nobody can make anything of still leaves a line: an incomplete
  # trace is worth more than none, and the gateway has erased the message by the
  # time we know we cannot use it.
  describe 'a message whose action no handler claims' do
    let(:message) { RetrievedMessageParser.new(real_envelope('requete').sub('ExecuteQueryRequest', 'SomethingElse')) }

    it 'names the action, and keeps what the header did carry' do
      audit_trail.message_unhandled(message:, message_id: 'message-passerelle')

      expect(journalled).to have_attributes(
        event_type: 'message_unhandled',
        ebms_action: 'SomethingElse',
        conversation_id: '1589c463-ccb7-4c0e-8044-c7198d844c16',
        exchange_id: '1647038b-7eaf-4711-b738-d5d83f96fa7b',
        message_id: 'message-passerelle',
        detail: 'Aucun traitement pour l\'action ebMS « SomethingElse »',
      )
    end

    # The same net as every other unreadable field: what the body would have
    # added is dropped rather than raised, so the line survives without it.
    it 'writes the line without the part when the part cannot be read either' do
      allow(message).to receive(:first_part).and_raise(UnreadableMessageError, 'partie illisible')

      audit_trail.message_unhandled(message:, message_id: 'message-passerelle')

      expect(journalled).to have_attributes(
        event_type: 'message_unhandled', ebms_action: 'SomethingElse',
        regrep_mime_type: nil, regrep_body: nil,
      )
    end
  end
end
