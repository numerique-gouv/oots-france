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

      it 'has its header name that provider as the original sender' do
        expect(property(header(body, EbmsAction::EXECUTE_QUERY_RESPONSE), 'originalSender'))
          .to eq([designated_id, designated_scheme])
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

    it 'has its header name France as the original sender' do
      french = EvidenceProvider.french.ebms_identity
      expect(property(header(body, EbmsAction::EXCEPTION_RESPONSE), 'originalSender')).to eq([french.id, french.type_id])
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

    it 'names the requester as the final recipient' do
      requester = message.body.requester.ebms_identity
      expect(property(envelope, 'finalRecipient')).to eq([requester.id, requester.type_id])
    end
  end
end
