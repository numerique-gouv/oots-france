require 'rails_helper'

# What chapter 4.8 has the journal record of an arriving message, read off the
# envelopes a real Domibus produced — and read on its own: not one line is
# written here, which is the whole point of the class. What becomes of these
# attributes is `AuditTrail`'s business, and `spec/lib/audit_trail_spec.rb`
# judges that end of it.
RSpec.describe JournalledMessage do
  def read(message, exchange: nil)
    described_class.new(message:, message_id: 'message-passerelle', exchange:).attributes
  end

  it 'writes nothing while it reads' do
    expect { read(RetrievedMessageParser.new(real_envelope('requete'))) }.not_to change(AuditEvent, :count)
  end

  describe 'a request another member state addressed to France' do
    subject(:attributes) { read(RetrievedMessageParser.new(real_envelope('requete'))) }

    it 'says what ties the exchange together, and what the header alone gives' do
      expect(attributes).to include(ebms_action: EbmsAction::EXECUTE_QUERY_REQUEST,
        conversation_id: '1589c463-ccb7-4c0e-8044-c7198d844c16', message_id: 'message-passerelle',
        request_id: 'urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700', procedure_code: '00')
    end

    it 'names the correspondent asking and France answering' do
      expect(attributes).to include(requesting_authority_id: '00000000000002',
        providing_authority_id: Settings.french_provider_identity[:id])
    end

    # Chapter 4.8, in both its tables: « MIME type and full content of first
    # MIME part ».
    it 'keeps the first MIME part whole, under the type the correspondent declared' do
      expect(attributes).to include(regrep_mime_type: 'application/x-ebrs+xml')
      expect(attributes[:regrep_body]).to include('query:QueryRequest')
    end
  end

  # The reason every field is read on its own and never inside one literal: a
  # literal evaluates all of them before it builds anything, so the one that
  # raises would take with it the ones already read — which are exactly what an
  # auditor has left.
  describe 'a request one field of which cannot be read' do
    subject(:attributes) { read(envelope_with_body('requete') { |body| body.sub('>ER<', '>IP<') }) }

    it 'keeps the fields it did read' do
      expect(attributes).to include(request_id: 'urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700',
        procedure_code: '00')
    end

    # The field is left out rather than named empty: the row it becomes has the
    # column null either way, and a reader of this hash learns which fields were
    # read.
    it 'leaves out the unreadable agent, and the country that travels on its address' do
      expect(attributes.keys).not_to include(:requesting_authority_id, :country_code)
    end

    # It comes from this deployment's own configuration, so it must not go down
    # with the correspondent's.
    it 'still names France, whose identity no correspondent supplies' do
      expect(attributes).to include(providing_authority_id: Settings.french_provider_identity[:id])
    end
  end

  describe 'an answer carrying evidence' do
    subject(:attributes) { read(message) }

    let(:message) { RetrievedMessageParser.new(real_envelope('reponseAvecPieceJointe')) }

    it 'says the three identifiers chapter 4.8 asks the response flow for' do
      expect(attributes).to include(
        request_id: 'urn:uuid:cdd87e02-2bdc-4ce6-bdc9-79e05adae700',
        response_id: '728c1aa1-5297-4d7c-9d7d-01fcce90075a',
        evidence_identifier: 'f114a58d-3f5e-46f1-b067-d53f88c6619b',
      )
    end

    it 'fingerprints the evidence, and never hands the evidence itself' do
      expect(attributes).to include(evidence_digest: Digest::SHA256.hexdigest(message.evidence.content),
        evidence_mime_type: 'application/pdf')
      expect(attributes.values).not_to include(message.evidence.content)
    end

    it 'names the party that answered, and the country read off its address' do
      expect(attributes).to include(providing_authority_id: '00000000000001', country_code: 'FR')
    end

    # Chapter 4.5.2 makes `sdg:IsAbout` the subject the provider confirms having
    # matched, where a request records the one that was asked for.
    it 'says the subject the provider confirms having matched' do
      expect(JSON.parse(attributes[:evidence_subject])).to include('family_name' => 'Dupont')
    end

    it 'says nothing broken of a response that breaks no rule' do
      expect(attributes[:detail]).to be_nil
    end
  end

  # The evidence fingerprint is read from the envelope and owes nothing to the
  # RegRep document, so a body Nokogiri refuses must not cost it.
  describe 'an answer whose body cannot be read, beside evidence that can' do
    subject(:attributes) { read(RetrievedMessageParser.new(envelope_with_unreadable_body)) }

    it 'still fingerprints the evidence the envelope did carry' do
      expect(attributes).to include(evidence_mime_type: 'application/pdf')
      expect(attributes[:evidence_digest]).to be_present
    end

    it 'reports the fields the body would have given as unread' do
      expect(attributes).to include(request_id: nil, detail: nil)
    end
  end

  # Chapter 4.6's rules and the inconsistency of chapter 4.7 §2.6.2 are judged
  # here and nowhere else: nothing is refused over them, so this column is the
  # only place the departure is ever read.
  describe 'an answer that does not conform' do
    subject(:attributes) { read(message, exchange:) }

    let(:message) { envelope_without_specification_slot('reponseAvecPieceJointe') }
    let(:exchange) { nil }

    # `R-EDM-RESP-S009` counts an announcement that is not there.
    it 'names what the response breaks' do
      expect(attributes[:detail]).to include('R-EDM-RESP-S009')
    end
  end

  # Its header still reads, so it says as much of itself as any arrival does.
  # What it cannot say is anything of a body no handler claims.
  describe 'a message whose action no handler claims' do
    subject(:attributes) { read(envelope_with_unknown_action) }

    it 'says what the envelope alone gives, and nothing of a body nobody claims' do
      expect(attributes).to include(ebms_action: 'UneActionInconnue', message_id: 'message-passerelle',
        regrep_mime_type: 'application/x-ebrs+xml')
      expect(attributes.keys).not_to include(:request_id, :evidence_digest, :detail)
    end
  end

  # Its header still reads, so it says as much of itself as any arrival does.
  def envelope_with_unknown_action
    document = Nokogiri::XML(real_envelope('requete'))
    document.at_xpath('//eb:Action', OotsNamespaces::NAMESPACES).content = 'UneActionInconnue'

    RetrievedMessageParser.new(document.to_xml)
  end
end
