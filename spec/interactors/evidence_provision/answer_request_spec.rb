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

      expect(AuditEvent.last).to have_attributes(event_type: 'error_sent', edm_error_code: 'EDM:ERR:0004')
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

  # France answering another member state opens no conversation of its own:
  # there is no row to mark failed, and therefore nothing to inspect after the
  # fact. A submission that fails must not be swallowed, or a foreign
  # correspondent goes unanswered with nothing but a log line to show for it.
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

  def code_of(document)
    document.at_xpath('//rs:Exception', 'rs' => 'urn:oasis:names:tc:ebxml-regrep:xsd:rs:4.0')['code']
  end
end
