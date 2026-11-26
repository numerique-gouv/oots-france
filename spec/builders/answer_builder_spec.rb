require 'rails_helper'

RSpec.describe AnswerBuilder do
  subject(:answers) { described_class.new(message:, request_id:, uuid: Oots::SequentialUuids.new) }

  let(:message) { envelope_with_provider_agent { designated_provider } }
  let(:request_id) { message.body.request_id }

  let(:designated_id) { '00000000-0000-0000-0000-000000000000' }
  let(:designated_scheme) { 'urn:oasis:names:tc:ebcore:partyid-type:unregistered:FR' }

  def designated_provider
    %(<sdg:Agent><sdg:Identifier schemeID="#{designated_scheme}">#{designated_id}</sdg:Identifier>) \
      '<sdg:Name lang="EN">FR - Test Evidence Provider</sdg:Name></sdg:Agent>'
  end

  def agent_identifier(body, slot, classification = nil)
    path = "//rim:Slot[@name='#{slot}']//sdg:Agent"
    path += "[sdg:Classification='#{classification}']" if classification
    identifier = Nokogiri::XML(body.render).at_xpath("#{path}/sdg:Identifier", SlotReading::NAMESPACES)
    [identifier.text, identifier['schemeID']]
  end

  def header(body, action) = Nokogiri::XML(answers.envelope(body, action).header)

  def property(header, name)
    found = header.at_xpath("//eb:Property[@name='#{name}']", OotsNamespaces::NAMESPACES)
    [found.text, found['type']]
  end

  def evidence_response
    answers.evidence_response(beneficiary: message.body.beneficiary, evidence_type: message.body.evidence_type,
      evidence_reference: OutgoingEnvelopeBuilder.payload_reference('reference'))
  end

  # `R-EDM-REQ_EDM-RESP-15` and `-16`, then `R-ebMS_EDM-RESP-01` and `-02`.
  {
    'the evidence response' => -> { evidence_response },
    'the empty list' => -> { answers.empty_response },
    'the deferred response' => -> { answers.deferred_response },
  }.each do |kind, build|
    describe kind do
      let(:body) { instance_exec(&build) }

      it 'announces as EP the provider the request names' do
        expect(agent_identifier(body, 'EvidenceProvider', 'EP')).to eq([designated_id, designated_scheme])
      end
    end
  end

  describe 'an error response' do
    let(:body) { answers.error_response(EdmException::OBJECT_NOT_FOUND) }

    it 'announces France as the error provider' do
      french = EvidenceProvider.french.ebms_identity
      expect(agent_identifier(body, 'ErrorProvider')).to eq([french.id, french.type_id])
    end

    it 'answers the request it was given the identifier of' do
      expect(Nokogiri::XML(body.render).root['requestId']).to eq(message.body.request_id)
    end

    context 'when the request identifier could not be read' do
      let(:request_id) { nil }

      it 'carries no requestId' do
        expect(Nokogiri::XML(body.render).root.key?('requestId')).to be(false)
      end
    end
  end

  describe 'the envelope' do
    subject(:envelope) { header(answers.empty_response, EbmsAction::EXECUTE_QUERY_RESPONSE) }

    def at(path) = envelope.at_xpath(path, OotsNamespaces::NAMESPACES)

    it 'goes back to the access point the request came from' do
      expect(at('//eb:PartyInfo/eb:To/eb:PartyId').text).to eq(message.sender.id)
    end

    it 'stays in the conversation and the exchange received' do
      expect(at('//eb:ConversationId').text).to eq(message.conversation_id)
      expect(property(envelope, 'ExchangeId').first).to eq(message.exchange_id)
    end
  end

  # Chapter 4.7 §2.4 and `R-ebMS_ebMS-05` to `-08`: the corners of the
  # request's header, swapped, whatever its body says — here an intermediary
  # platform as `originalSender` and another provider as `finalRecipient`.
  describe 'the corners of a request whose header names other parties than its body' do
    let(:sender) { ['0671516647', 'urn:cef.eu:names:identifier:EAS:0208'] }
    let(:recipient) { ['13000247900016', 'urn:cef.eu:names:identifier:EAS:0002'] }
    let(:message) { readdressed_both(envelope_with_provider_agent { designated_provider }) }

    def readdressed_both(received)
      readdressed(readdressed(received, 'originalSender', id: sender.first, type: sender.last),
        'finalRecipient', id: recipient.first, type: recipient.last)
    end

    def preview_required
      answers.error_response(EdmException::AUTHORIZATION, preview_location: 'https://oots.example/previsualisation/x')
    end

    {
      'the evidence response' => [-> { evidence_response }, EbmsAction::EXECUTE_QUERY_RESPONSE],
      'the empty list' => [-> { answers.empty_response }, EbmsAction::EXECUTE_QUERY_RESPONSE],
      'the deferred response' => [-> { answers.deferred_response }, EbmsAction::EXECUTE_QUERY_RESPONSE],
      'an error response' => [-> { answers.error_response(EdmException::OBJECT_NOT_FOUND) },
                              EbmsAction::EXCEPTION_RESPONSE],
      'the PreviewRequired error' => [-> { preview_required }, EbmsAction::EXCEPTION_RESPONSE],
    }.each do |kind, (build, action)|
      { 'on the 2.0 line' => -> { envelope_with_provider_agent { designated_provider } },
        'on the 1.2 line' => -> { earlier_line_envelope { |body| body.sub(Fixtures::PROVIDER_AGENT) { designated_provider } } } }
        .each do |line, received|
        describe "#{kind}, #{line}" do
          subject(:envelope) { header(instance_exec(&build), action) }

          let(:message) { readdressed_both(instance_exec(&received)) }

          it 'is addressed to the original sender of the request' do
            expect(property(envelope, 'finalRecipient')).to eq(sender)
          end

          it 'comes from the final recipient of the request' do
            expect(property(envelope, 'originalSender')).to eq(recipient)
          end

          it 'names nothing of the requester its body announces' do
            expect(envelope.to_xml).not_to include(message.body.requester.ebms_identity.id)
          end
        end
      end
    end

    it 'leaves the provider the request names as the EP of the response' do
      expect(agent_identifier(evidence_response, 'EvidenceProvider', 'EP')).to eq([designated_id, designated_scheme])
    end

    it 'leaves France as the error provider' do
      french = EvidenceProvider.french.ebms_identity
      expect(agent_identifier(answers.error_response(EdmException::OBJECT_NOT_FOUND), 'ErrorProvider'))
        .to eq([french.id, french.type_id])
    end

    it 'copies the values as they are, surrounding whitespace included' do
      message = readdressed(envelope_with_provider_agent { designated_provider }, 'originalSender',
        id: " #{sender.first} ", type: sender.last)
      answers = described_class.new(message:, request_id:, uuid: Oots::SequentialUuids.new)
      envelope = Nokogiri::XML(answers.envelope(answers.empty_response, EbmsAction::EXECUTE_QUERY_RESPONSE).header)

      expect(property(envelope, 'finalRecipient').first).to eq(" #{sender.first} ")
    end
  end
end
