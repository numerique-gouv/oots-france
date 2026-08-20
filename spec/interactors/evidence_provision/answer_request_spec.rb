require 'rails_helper'

# The inbound side: another member state asks France for evidence. Nothing here
# was covered before — the only path ever exercised was the happy one, and only
# by the end-to-end scenarios, which need a live gateway.
RSpec.describe EvidenceProvision::AnswerRequest do
  subject(:answer) { described_class.call(message:, gateway:, uuid: Oots::SequentialUuids.new, audit_trail: AuditTrail.new) }

  let(:gateway) { gateway_accepting_submissions }
  let(:message) { RetrievedMessageParser.new(real_envelope('requete')) }

  def submitted = gateway_body.then { |body| Nokogiri::XML(decoded_payload(body)) }

  it 'serves the evidence for the system-check procedure' do
    answer

    expect(submitted.root.name).to eq('QueryResponse')
    expect(status_of(submitted)).to end_with('Success')
  end

  # Chapter 4.8 puts the evidence response identifier and the fingerprint of the
  # evidence among what a provider must log.
  it 'journals what France answered' do
    answer

    expect(AuditEvent.last).to have_attributes(
      event_type: 'response_sent',
      conversation_id: message.conversation_id,
      message_id: 'message-passerelle',
      exchange_id: message.exchange_id,
      request_id: message.body.request_id,
      edm_error_code: nil,
      evidence_digest: Digest::SHA256.hexdigest(Rails.root.join(described_class::EVIDENCE_PATH).binread),
      # The identifier of France's own answer: chapter 4.8 walks the
      # non-repudiation chain from it, and it is what `Answer` carries.
      response_id: identifier_of(submitted),
      # Where France answers, the country logged is the one the request named:
      # `R-EDM-REQ-C073` puts it on the agent classified `ER`, and France's own
      # response carries no address for that agent.
      country_code: 'FR',
    )
  end

  it 'attaches the document France holds' do
    answer

    payloads = Nokogiri::XML(gateway_body).xpath('//payload')

    expect(payloads.size).to eq(2)
    expect(Base64.decode64(payloads.last.at_xpath('value').text)).to start_with('%PDF')
  end

  # Any procedure other than the system check: France has no provider connected,
  # and says so with the code the TDD prescribe rather than staying silent.
  describe 'a procedure it does not serve' do
    let(:message) { RetrievedMessageParser.new(real_envelope('requete.demarcheInconnue')) }

    it 'answers EDM:ERR:0004' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0004')
    end

    it 'journals the refusal under the code it answered with' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0004',
        country_code: 'FR')
    end
  end

  # An unsupported optional capability, not an invalid request: the correspondent
  # asked for a distribution format we do not serve.
  describe 'a distribution format it does not serve' do
    let(:message) { envelope_with_body('requete') { |body| body.sub('application/pdf', 'application/xml') } }

    it 'answers EDM:ERR:0007' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0007')
    end

    it 'journals the refusal under the code it answered with' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0007')
    end
  end

  describe 'a request it cannot read past the requester' do
    let(:message) do
      envelope_with_body('requete') { |body| body.sub(%r{<rim:Slot name="Procedure">.*?</rim:Slot>}m, '') }
    end

    # Readable enough to answer, not enough to serve. Silence would teach the
    # correspondent nothing.
    it 'answers EDM:ERR:0003 rather than nothing at all' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
    end

    it 'journals the refusal under the code it answered with' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0003')
    end

    # A slot the reader could not find is not a rule with a number: the answer
    # degrades to the bare code rather than inventing an identifier for it.
    it 'writes no detail when no rule names the failure' do
      answer

      expect(detail_of(submitted)).to be_nil
    end
  end

  # Chapter 4.6 through and through: a request that is well formed and still not
  # one France may answer. What the correspondent gets back names the rule.
  describe 'a request that breaks a business rule' do
    let(:message) do
      envelope_with_body('requete') { |body| body.sub(%r{<rim:Slot name="PossibilityForPreview">.*?</rim:Slot>}m, '') }
    end

    it 'answers EDM:ERR:0003 naming the rule it applied' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq('R-EDM-REQ-S009')
    end

    # Article 17 asks for the errors as much as the exchanges, and a refusal
    # whose reason is not recorded cannot be answered for afterwards.
    it 'journals the rule alongside the code' do
      answer

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0003',
        detail: 'R-EDM-REQ-S009')
    end
  end

  # Chapter 4.4: « A Data Service MUST reject requests that use identifiers that
  # were used in previously processed requests. »
  describe 'a request whose identifier has already been answered' do
    subject(:answer) do
      described_class.call(message:, gateway:, message_id: 'message-en-cours',
        uuid: Oots::SequentialUuids.new, audit_trail: AuditTrail.new)
    end

    before do
      create(:audit_event, event_type: 'request_received', request_id: message.body.request_id,
        message_id: 'message-precedent')
    end

    it 'refuses it rather than serving the evidence twice' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq(described_class::REPLAYED_IDENTIFIER)
    end

    # `IncomingMessage::Process` journals an arrival before it dispatches, so
    # the request being answered has a line of its own here. Counting it would
    # make every request its own replay.
    context 'when the only line is the arrival of this very message' do
      before do
        AuditEvent.delete_all
        create(:audit_event, event_type: 'request_received', request_id: message.body.request_id,
          message_id: 'message-en-cours')
      end

      it 'serves the evidence' do
        answer

        expect(status_of(submitted)).to end_with('Success')
      end
    end
  end

  # The version travels twice, and no rule says the two must agree: each is
  # pinned to the same literal on its own — R-EDM-ebMS-038 for the header
  # property, R-EDM-REQ-C001 for the body slot — so they agree by transitivity,
  # and a header saying otherwise is a message no reading can reconcile.
  describe 'a request whose header contradicts its body on the version' do
    let(:message) do
      RetrievedMessageParser.new(real_envelope('requete').sub(EdmSpecification::IDENTIFIER, 'oots-edm:v1.0'))
    end

    it 'answers EDM:ERR:0003 naming the ebMS rule' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq('R-EDM-ebMS-038')
    end
  end

  # R-EDM-ebMS-019 makes the property mandatory, where -038 fixes its value: two
  # rules, two details on the wire, and a correspondent who omitted the property
  # is not one who declared the wrong version.
  describe 'a request whose header omits the version altogether' do
    let(:message) do
      RetrievedMessageParser.new(
        real_envelope('requete').sub(%r{<[^>]*Property name="SpecificationId">.*?</[^>]*Property>}m, ''),
      )
    end

    it 'answers EDM:ERR:0003 naming the rule that requires the property' do
      answer

      expect(code_of(submitted)).to eq('EDM:ERR:0003')
      expect(detail_of(submitted)).to eq('R-EDM-ebMS-019')
    end
  end

  describe 'a request whose requester cannot be read' do
    let(:message) { envelope_with_body('requete') { |body| body.gsub('>ER<', '>IP<') } }

    # No requester means no final recipient: an answer would be addressed to
    # nobody. The failure has to propagate rather than produce such a message.
    it 'gives up rather than answering nobody' do
      expect { answer }.to raise_error(UnreadableMessageError, /ER/)
      expect(gateway).not_to have_received(:submit)
    end
  end

  # The received request opened its exchange: swallowed here, the failure would
  # leave it pending a sequel that is never coming, and it is `Process` that
  # settles it on seeing the error come back up.
  it 'lets a failure to submit the answer surface' do
    allow(gateway).to receive(:submit).and_raise(Faraday::ConnectionFailed, 'connexion refusée')

    expect { answer }.to raise_error(Faraday::ConnectionFailed)
  end

  it 'answers under the exchange identifier it received' do
    answer

    exchange = Nokogiri::XML(gateway_body).at_xpath('//eb:Property[@name="ExchangeId"]', OotsNamespaces::NAMESPACES)

    expect(exchange.text).to eq(message.exchange_id)
  end

  def gateway_body
    expect(gateway).to have_received(:submit) { |envelope| return envelope }
  end

  def decoded_payload(envelope) = Base64.decode64(Nokogiri::XML(envelope).at_xpath('//payload/value').text)

  def status_of(document) = document.root['status']

  def identifier_of(document)
    document.at_xpath("//rim:Slot[@name='EvidenceResponseIdentifier']//rim:Value", SlotReading::NAMESPACES).text
  end

  def code_of(document) = exception_of(document)['code']

  def detail_of(document) = exception_of(document)['detail']

  def exception_of(document)
    document.at_xpath('//rs:Exception', 'rs' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0')
  end
  # The bridge between answering another member state and closing the exchange
  # opened on receiving its request. Without it, an answer goes out and the
  # exchange stays pending a sequel that is never coming.
  describe 'the exchange France opened on receiving the request' do
    before { create(:conversation, incoming: true, conversation_id: message.conversation_id, country_code: nil) }

    it 'is delivered once the evidence has gone out' do
      answer

      expect(Conversation.sole).to have_attributes(status: 'delivered')
    end

    # A refusal settles the exchange as surely as an answer does: what the
    # correspondent is owed has gone out either way, and an exchange left
    # pending would claim a sequel that is never coming.
    context 'when France refuses what was asked' do
      let(:message) { RetrievedMessageParser.new(real_envelope('requete.demarcheInconnue')) }

      it 'fails under the code France answered with' do
        answer

        expect(Conversation.sole).to have_attributes(status: 'failed', edm_error_code: 'EDM:ERR:0004')
      end
    end
  end

  # The same identifier can name an exchange France opened by asking: settling
  # it here would call it delivered, and the response it is really waiting for
  # would no longer settle it.
  it 'leaves alone an exchange France opened by asking' do
    create(:conversation, conversation_id: message.conversation_id, incoming: false)
    allow(Rails.logger).to receive(:warn)

    answer

    expect(Conversation.sole).to have_attributes(status: 'pending')
  end

  # `IncomingMessage::Process` always opens one, but nothing compels it: the
  # answer goes out all the same, and says so rather than letting it slip.
  it 'answers all the same when no exchange bears the identifier received' do
    expect(Rails.logger).to receive(:warn).with(/#{message.conversation_id}/)

    expect(answer).to be_a_success
  end
end
